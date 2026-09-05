#!/usr/bin/env python3
# KevinTech Telegram Bot - panel de usuarios + super admin
import os,re,json,time,threading,subprocess,urllib.request,urllib.parse,shlex,datetime,io,secrets
from pathlib import Path

BASE=Path('/etc/kevintech'); TD=BASE/'telegram'; ENV=TD/'.env'; LOG=TD/'logs'/'bot.log'; OFF=TD/'offset'
DB=TD/'data.json'; BACK=TD/'backups'; STATE={}; CHAT_TYPES={}; API=''; OWNER=0; BOT_USERNAME=''


DEFAULT_MONETIZATION_HTML=r"""<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>KevinTech System</title><script src="https://telegram.org/js/telegram-web-app.js"></script><script src="https://libtl.com/sdk.js" data-zone="11217882" data-sdk="show_11217882"></script><style>*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#05070d;color:#fff;font-family:Arial,sans-serif;display:flex;align-items:center;justify-content:center;overflow:hidden}.background{position:fixed;inset:0}.grid{position:absolute;inset:0;background-image:linear-gradient(rgba(0,220,255,.08) 1px,transparent 1px),linear-gradient(90deg,rgba(0,220,255,.08) 1px,transparent 1px);background-size:42px 42px;transform:perspective(500px) rotateX(55deg) scale(1.8);transform-origin:center bottom}.particles span{position:absolute;width:4px;height:4px;border-radius:50%;background:#00e5ff;opacity:.6;animation:float 5s infinite}.particles span:nth-child(1){left:15%;top:25%}.particles span:nth-child(2){left:78%;top:20%}.particles span:nth-child(3){left:35%;top:70%}.particles span:nth-child(4){left:65%;top:75%}.particles span:nth-child(5){left:25%;top:50%}.particles span:nth-child(6){left:85%;top:55%}@keyframes float{50%{transform:translateY(-22px);opacity:1}}.app{width:min(92vw,430px);position:relative}.panel{padding:30px 22px;border:1px solid rgba(0,229,255,.28);border-radius:28px;background:rgba(7,10,18,.9);box-shadow:0 0 55px rgba(0,229,255,.1);text-align:center}.logo-area{height:120px;position:relative;display:flex;align-items:center;justify-content:center}.logo{width:78px;height:78px;border:2px solid #00e5ff;border-radius:22px;display:flex;align-items:center;justify-content:center;font-size:30px;font-weight:900;letter-spacing:2px;box-shadow:0 0 30px rgba(0,229,255,.35)}.ring{position:absolute;border:1px solid rgba(0,229,255,.22);border-radius:50%;animation:spin 8s linear infinite}.one{width:104px;height:104px}.two{width:128px;height:70px;transform:rotate(35deg)}.three{width:145px;height:145px}@keyframes spin{to{transform:rotate(360deg)}}.mini-title{font-size:12px;letter-spacing:3px;color:#8ea0b8;text-transform:uppercase}h1{font-size:28px;margin:8px 0 12px}h1 span{color:#00e5ff}.description{color:#aeb8c7;line-height:1.55;font-size:14px}.status{display:inline-flex;align-items:center;gap:8px;margin:10px 0 20px;padding:8px 12px;border-radius:99px;background:rgba(0,229,255,.07);font-size:12px}.status-dot{width:8px;height:8px;border-radius:50%;background:#00ff8c;box-shadow:0 0 10px #00ff8c}.button-wrap{position:relative}.glow{position:absolute;inset:4px;border-radius:18px;filter:blur(15px);background:rgba(0,229,255,.28)}button{position:relative;width:100%;border:1px solid rgba(0,229,255,.6);border-radius:18px;padding:16px;background:#09131d;color:#fff;font-weight:800;letter-spacing:1px;font-size:15px;cursor:pointer}button:disabled{opacity:.7}.loader{display:none;width:15px;height:15px;border:2px solid #789;border-top-color:#00e5ff;border-radius:50%;animation:spin .7s linear infinite;margin-right:8px;vertical-align:-2px}.footer{margin-top:22px;color:#68768a;font-size:12px}.footer a{color:#00e5ff;text-decoration:none}#error-msg{display:none}.error-icon{font-size:38px}.continue{margin-top:10px}.error-msg{}.particles span{background:#00e5ff}</style></head><body><div class="background"><div class="grid"></div><div class="particles"><span></span><span></span><span></span><span></span><span></span><span></span></div></div><main class="app"><section class="panel"><div class="logo-area"><div class="ring one"></div><div class="ring two"></div><div class="ring three"></div><div class="logo">KT</div></div><div id="loading"><div class="mini-title">KevinTech System</div><h1><span>Acceso Premium</span></h1><p class="description">Estás a un paso de continuar. Mira un pequeño anuncio para mantener este servicio disponible gratuitamente.</p><div class="status"><span class="status-dot"></span>Sistema disponible</div><div class="button-wrap"><div class="glow"></div><button id="playBtn"><span id="loader" class="loader"></span><span id="btnText">▶ &nbsp; VER ANUNCIO</span></button></div></div><div id="error-msg"><div class="error-icon">⚠️</div><div class="mini-title">KevinTech System</div><h1>Anuncio no disponible</h1><p class="description">En este momento no hay publicidad disponible para tu región.</p><button class="continue" onclick="sendSuccessAndClose()">✓ CONTINUAR</button></div><div class="footer"><p>© KevinTech Multi Script</p><p><a href="https://youtube.com/@kevinaldaircama" target="_blank">YouTube</a>&nbsp;•&nbsp;<a href="https://whatsapp.com/channel/0029VaGmNBB4Y9lvO2Ppem2l" target="_blank">WhatsApp</a></p></div></section></main><script>const tg=window.Telegram.WebApp;tg.ready();tg.expand();const playBtn=document.getElementById('playBtn'),btnText=document.getElementById('btnText'),loader=document.getElementById('loader'),loading=document.getElementById('loading'),errorMsg=document.getElementById('error-msg');const params=new URLSearchParams(location.search),token=params.get('token')||'';const botBase=__BOT_URL_JSON__;const sdkCode=__SDK_CODE_JSON__;const rewardCode=__REWARD_CODE_JSON__;function sendSuccessAndClose(){const payload=JSON.stringify({type:'adcompleted',token:token});try{if(tg&&typeof tg.sendData==='function'&&token){tg.sendData(payload);setTimeout(()=>tg.close(),250);return}}catch(e){}const url=botBase+(botBase.includes('?')?'&':'?')+'start=adcompleted_'+encodeURIComponent(token);try{tg.openTelegramLink(url);setTimeout(()=>tg.close(),400)}catch(e){location.href=url}}function showError(){loading.style.display='none';errorMsg.style.display='block'}function inject(code){if(!code)return;const box=document.createElement('div');box.innerHTML=code;[...box.querySelectorAll('script')].forEach(old=>{const n=document.createElement('script');[...old.attributes].forEach(a=>n.setAttribute(a.name,a.value));n.textContent=old.textContent;document.body.appendChild(n)});return box}async function play(){playBtn.disabled=true;loader.style.display='inline-block';btnText.textContent='CARGANDO ANUNCIO...';try{inject(sdkCode);inject(rewardCode);await new Promise(r=>setTimeout(r,350));let fn=Object.keys(window).find(k=>/^show_\d+$/.test(k)&&typeof window[k]==='function');if(!fn)throw new Error('SDK');await window[fn]();loader.style.display='none';btnText.textContent='✓ COMPLETADO';setTimeout(sendSuccessAndClose,600)}catch(err){loader.style.display='none';showError()}}playBtn.addEventListener('click',play);</script></body></html>"""

DEFAULT={
 'access':'private','admins':{},'bans':{},'users':{},
 'quotas':{'public_days':7,'public_devices':1,'admin_days':30,'admin_devices':2},
 'security':{'auto_ban_ssh':False,'violations':{}},
 'monetization':{'monetag':''},
 'auto_update':{'enabled':False,'last_version':'','checked_at':0},
 'backup_schedule':{'mode':'once','next_at':0},
 'ad_tokens':{},
 'chat_messages':{},
 'ad_pending':{},
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
 d['monetization'].pop('',None)
 if not isinstance(d.get('backup_schedule'),dict):d['backup_schedule']=json.loads(json.dumps(DEFAULT['backup_schedule']))
 d['backup_schedule'].setdefault('mode','once');d['backup_schedule'].setdefault('next_at',0)
 if not isinstance(d.get('ad_tokens'),dict):d['ad_tokens']={}
 if not isinstance(d.get('chat_messages'),dict):d['chat_messages']={}
 if not isinstance(d.get('ad_pending'),dict):d['ad_pending']={}
 now=time.time();
 d['ad_pending']={k:v for k,v in d['ad_pending'].items() if isinstance(v,dict) and float(v.get('expires',0) or 0)>now}
 d['ad_tokens']={k:v for k,v in d['ad_tokens'].items() if isinstance(v,dict) and float(v.get('expires',0) or 0)>now}
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
 'users':{'es':'👤 <b>GESTIÓN DE CUENTAS</b>\n\nCrea y consulta tus cuentas, revisa las conexiones activas, elimina accesos cuando lo necesites y utiliza las opciones disponibles para tu nivel de acceso.','en':'👤 <b>USERS</b>\n\nManage your accounts.','pt':'👤 <b>USUÁRIOS</b>\n\nGerencie suas contas.'},
 'info':{'es':'ℹ️ <b>INFORMACIÓN</b>\n\nEste bot te permite gestionar tus accesos desde Telegram: crear cuentas normales o V2Ray, consultar tus cuentas, revisar conexiones, renovar, eliminar y usar el sistema de referidos. Las cuotas definidas por el super admin se aplican automáticamente a los usuarios públicos.','en':'ℹ️ <b>INFORMATION</b>\n\nThis bot lets you create and manage your server access accounts, view your accounts, check connections and manage referrals.','pt':'ℹ️ <b>INFORMAÇÕES</b>\n\nEste bot permite criar e gerenciar suas contas de acesso ao servidor, consultar suas contas, ver conexões e gerenciar indicações.'},
 'choose_lang':{'es':'🌎 <b>SELECCIONA TU IDIOMA</b>\n\nElige el idioma de la interfaz. Puedes cambiarlo cuando quieras desde el menú de idioma.\n\n🌐 <b>13 idiomas disponibles</b>.','en':'🌎 <b>Select your language</b>\n\nChoose the language you want to use.','pt':'🌎 <b>Selecione seu idioma</b>\n\nEscolha o idioma que deseja usar.'},
 'settings':{'es':'⚙️ <b>CENTRO DEL SUPER ADMIN</b>\n\nControl total del panel: usuarios, administradores, seguridad, cuotas, monetización, respaldos, herramientas y mantenimiento del servidor.','en':'⚙️ <b>SUPER ADMIN SETTINGS</b>\n\nCentral panel controls.','pt':'⚙️ <b>AJUSTES DO SUPER ADMIN</b>\n\nControles centrais do painel.'},
 'language_saved':{'es':'🟢 Idioma guardado.','en':'🟢 Language saved.','pt':'🟢 Idioma salvo.'},
}
# Textos principales traducidos para los 13 idiomas.
I18N.update({
 'home':{
  'es':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Centro de control</b>\n\nGestiona tus accesos desde Telegram de forma rápida, clara y segura. Crea cuentas, consulta conexiones, revisa tu actividad y administra tus servicios desde un solo lugar.',
  'en':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Main panel</b>\n\nManage your accounts quickly and easily from Telegram.',
  'pt':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Painel principal</b>\n\nGerencie suas contas de forma rápida e simples pelo Telegram.',
  'fr':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Panneau principal</b>\n\nGérez vos comptes rapidement et facilement depuis Telegram.',
  'de':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Hauptmenü</b>\n\nVerwalte deine Konten schnell und einfach über Telegram.',
  'it':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Pannello principale</b>\n\nGestisci i tuoi account in modo semplice e veloce da Telegram.',
  'ru':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Главное меню</b>\n\nУправляйте аккаунтами быстро и удобно через Telegram.',
  'tr':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Ana panel</b>\n\nHesaplarınızı Telegram üzerinden hızlı ve kolay yönetin.'
 },
 'users':{
  'es':'👤 <b>GESTIÓN DE CUENTAS</b>\n\nCrea y consulta tus cuentas, revisa las conexiones activas, elimina accesos cuando lo necesites y utiliza las opciones disponibles para tu nivel de acceso.',
  'en':'👤 <b>USERS</b>\n\nManage your accounts.',
  'pt':'👤 <b>USUÁRIOS</b>\n\nGerencie suas contas.',
  'fr':'👤 <b>UTILISATEURS</b>\n\nGérez vos comptes.',
  'de':'👤 <b>BENUTZER</b>\n\nVerwalte deine Konten.',
  'it':'👤 <b>UTENTI</b>\n\nGestisci i tuoi account.',
  'ru':'👤 <b>ПОЛЬЗОВАТЕЛИ</b>\n\nУправляйте аккаунтами.',
  'tr':'👤 <b>KULLANICILAR</b>\n\nHesaplarınızı yönetin.'
 },
 'info':{
  'es':'ℹ️ <b>CENTRO DE INFORMACIÓN</b>\n\nKevinTech reúne en un solo bot la gestión de cuentas, conexiones, renovaciones, referidos, configuración y herramientas del servidor. Las opciones visibles dependen de tus permisos.',
  'en':'ℹ️ <b>INFORMATION</b>\n\nThis bot lets you manage access, accounts, connections, renewals and referrals.',
  'pt':'ℹ️ <b>INFORMAÇÕES</b>\n\nEste bot permite gerenciar acessos, contas, conexões, renovações e indicações.',
  'fr':'ℹ️ <b>INFORMATIONS</b>\n\nCe bot vous permet de gérer vos accès, comptes, connexions, renouvellements et parrainages.',
  'de':'ℹ️ <b>INFORMATIONEN</b>\n\nMit diesem Bot kannst du Zugänge, Konten, Verbindungen, Verlängerungen und Empfehlungen verwalten.',
  'it':'ℹ️ <b>INFORMAZIONI</b>\n\nQuesto bot permette di gestire accessi, account, connessioni, rinnovi e referral.',
  'ru':'ℹ️ <b>ИНФОРМАЦИЯ</b>\n\nБот позволяет управлять доступами, аккаунтами, подключениями, продлениями и рефералами.',
  'tr':'ℹ️ <b>BİLGİ</b>\n\nBu bot erişimleri, hesapları, bağlantıları, yenilemeleri ve referansları yönetmenizi sağlar.'
 },
 'choose_lang':{
  'es':'🌎 <b>SELECCIONA TU IDIOMA</b>\n\nElige el idioma de la interfaz. Puedes cambiarlo cuando quieras desde el menú de idioma.\n\n🌐 <b>13 idiomas disponibles</b>.',
  'en':'🌎 <b>Select your language</b>\n\nChoose the language you want to use.',
  'pt':'🌎 <b>Selecione seu idioma</b>\n\nEscolha o idioma que deseja usar.',
  'fr':'🌎 <b>Choisissez votre langue</b>\n\nSélectionnez la langue à utiliser.',
  'de':'🌎 <b>Sprache auswählen</b>\n\nWähle die gewünschte Sprache.',
  'it':'🌎 <b>Seleziona la lingua</b>\n\nScegli la lingua che vuoi usare.',
  'ru':'🌎 <b>Выберите язык</b>\n\nВыберите язык, который хотите использовать.',
  'tr':'🌎 <b>Dilinizi seçin</b>\n\nKullanmak istediğiniz dili seçin.'
 },
 'settings':{
  'es':'⚙️ <b>CENTRO DEL SUPER ADMIN</b>\n\nControl total del panel: usuarios, administradores, seguridad, cuotas, monetización, respaldos, herramientas y mantenimiento del servidor.',
  'en':'⚙️ <b>SUPER ADMIN SETTINGS</b>\n\nCentral panel controls.',
  'pt':'⚙️ <b>AJUSTES DO SUPER ADMIN</b>\n\nControles centrais do painel.',
  'fr':'⚙️ <b>PARAMÈTRES SUPER ADMIN</b>\n\nContrôle central du panneau.',
  'de':'⚙️ <b>SUPER-ADMIN-EINSTELLUNGEN</b>\n\nZentrale Steuerung des Panels.',
  'it':'⚙️ <b>IMPOSTAZIONI SUPER ADMIN</b>\n\nControllo centrale del pannello.',
  'ru':'⚙️ <b>НАСТРОЙКИ СУПЕР-АДМИНА</b>\n\nЦентральное управление панелью.',
  'tr':'⚙️ <b>SÜPER ADMİN AYARLARI</b>\n\nPanelin merkezi kontrolü.'
 }
})

def tr(uid,key):return I18N.get(key,I18N['home']).get(lang(uid),I18N.get(key,I18N['home'])['es'])
def language_keyboard(uid):
 langs=['es','en','pt','fr','de','it','ru','tr','zh','ja','ko','id','ar']
 return [[{'text':LANG_NAMES[k],'callback_data':'lang:'+k} for k in langs[i:i+2]] for i in range(0,len(langs),2)]

LANG_NAMES={
 'es':'🇪🇸 Español','en':'🇺🇸 English','pt':'🇧🇷 Português','fr':'🇫🇷 Français',
 'de':'🇩🇪 Deutsch','it':'🇮🇹 Italiano','ru':'🇷🇺 Русский','tr':'🇹🇷 Türkçe',
 'zh':'🇨🇳 中文','ja':'🇯🇵 日本語','ko':'🇰🇷 한국어','id':'🇮🇩 Bahasa Indonesia','ar':'🇸🇦 العربية',
}
BUTTONS={
 'es':{'users':'👤 Usuarios','referrals':'🔗 Referidos','language':'🌐 Idioma','info':'ℹ️ Información','settings':'⚙️ Ajustes','home':'🔙 Inicio','create':'➕ Crear cuenta','renew':'♻️ Renovar','list':'📋 Lista','online':'🟢 Online','account':'👤 Cuenta','delete':'🗑️ Eliminar cuenta','cancel':'❌ Cancelar','monetization':'💰 Monetización','monetag':'💰 Monetag','monetag_config':'⚙️ Configurar','monetag_delete':'🗑️ Eliminar','monetag_toggle_on':'🟢 Encender','monetag_toggle_off':'⛔ Apagar','system_update':'🔄 Actualizar sistema','system_update_now':'⬇️ Actualizar ahora','auto_update_toggle_on':'🤖 Activar automática','auto_update_toggle_off':'⛔ Desactivar automática','admin_list':'📋 Lista de admins','admin_add':'➕ Agregar admin','admin_remove':'🗑️ Quitar admin','admin_rename':'✏️ Renombrar admin','backup_restore':'💾 Respaldos y restauración','backup_menu':'💾 Respaldos y restauración','backup_now':'📤 Enviar ahora','restore':'♻️ Restaurar','quotas':'📅 Cuotas','restart_vps':'♻️ Reiniciar VPS','security':'🛡️ Seguridad','tools':'🛠 Herramientas','people':'👥 Personas registradas','message_users':'📢 Mensaje a usuarios','bans':'🚫 Banear usuario','domain':'🌐 Dominio','access_toggle':'🔐 Acceso','ref_renew':'🎁 Cangear 7 días (3 referidos)','create:normal':'👤 Cuenta normal','create:v2ray':'🚀 Cuenta V2Ray','backup:daily':'📅 Enviar diario','backup:7d':'7️⃣ Cada 7 días','backup:15d':'1️⃣5️⃣ Cada 15 días','backup:30d':'3️⃣0️⃣ Cada 30 días','backup:once':'☝️ Solo una vez','tool:firewall':'🔥 Firewall','tool:optimizar':'🚀 Optimizar','tool:ads':'🚫 Ads','tool:torrent':'🚫 Torrent','tool:speed':'📈 Speedtest','tool:scanner':'🔎 Scanner','tool:files':'📁 Archivos','security:auto':'🛡️ Auto banea SSH','quota_public':'👥 Público','quota_admin':'👨‍💼 Admin','ban_add':'🚫 Banear usuarios','ban_remove':'🔓 Desbanear','ban_list':'📋 Lista de ban'},
 'en':{'users':'👤 Users','referrals':'🔗 Referrals','language':'🌐 Language','info':'ℹ️ Information','settings':'⚙️ Settings','home':'🔙 Home','create':'➕ Create account','renew':'♻️ Renew','list':'📋 List','online':'🟢 Online','account':'👤 Account','delete':'🗑️ Delete account','cancel':'❌ Cancel','monetization':'💰 Monetization','monetag':'💰 Monetag','monetag_config':'⚙️ Configure','monetag_delete':'🗑️ Delete','monetag_toggle_on':'🟢 Enable','monetag_toggle_off':'⛔ Disable','system_update':'🔄 Update system','system_update_now':'⬇️ Update now','auto_update_toggle_on':'🤖 Enable automatic','auto_update_toggle_off':'⛔ Disable automatic','admin_list':'📋 Admin list','admin_add':'➕ Add admin','admin_remove':'🗑️ Remove admin','admin_rename':'✏️ Rename admin','backup_restore':'💾 Backup & restore','backup_menu':'💾 Backup & restore','backup_now':'📤 Send now','restore':'♻️ Restore','quotas':'📅 Quotas','restart_vps':'♻️ Restart VPS','security':'🛡️ Security','tools':'🛠 Tools','people':'👥 Registered users','message_users':'📢 Message users','bans':'🚫 Ban user','domain':'🌐 Domain','access_toggle':'🔐 Access','ref_renew':'🎁 Redeem 7 days (3 referrals)','create:normal':'👤 Normal account','create:v2ray':'🚀 V2Ray account','backup:daily':'📅 Send daily','backup:7d':'7️⃣ Every 7 days','backup:15d':'1️⃣5️⃣ Every 15 days','backup:30d':'3️⃣0️⃣ Every 30 days','backup:once':'☝️ Once','tool:firewall':'🔥 Firewall','tool:optimizar':'🚀 Optimize','tool:ads':'🚫 Ads','tool:torrent':'🚫 Torrent','tool:speed':'📈 Speedtest','tool:scanner':'🔎 Scanner','tool:files':'📁 Files','security:auto':'🛡️ Auto-ban SSH','quota_public':'👥 Public','quota_admin':'👨‍💼 Admin','ban_add':'🚫 Ban users','ban_remove':'🔓 Unban','ban_list':'📋 Ban list'},
 'pt':{'users':'👤 Usuários','referrals':'🔗 Indicações','language':'🌐 Idioma','info':'ℹ️ Informações','settings':'⚙️ Configurações','home':'🔙 Início','create':'➕ Criar conta','renew':'♻️ Renovar','list':'📋 Lista','online':'🟢 Online','account':'👤 Conta','delete':'🗑️ Excluir conta','cancel':'❌ Cancelar','monetization':'💰 Monetização','monetag':'💰 Monetag','monetag_config':'⚙️ Configurar','monetag_delete':'🗑️ Excluir','monetag_toggle_on':'🟢 Ativar','monetag_toggle_off':'⛔ Desativar','system_update':'🔄 Atualizar sistema','system_update_now':'⬇️ Atualizar agora','auto_update_toggle_on':'🤖 Ativar automática','auto_update_toggle_off':'⛔ Desativar automática','admin_list':'📋 Lista de admins','admin_add':'➕ Adicionar admin','admin_remove':'🗑️ Remover admin','admin_rename':'✏️ Renomear admin','backup_restore':'💾 Backup e restauração','backup_menu':'💾 Backup e restauração','backup_now':'📤 Enviar agora','restore':'♻️ Restaurar','quotas':'📅 Cotas','restart_vps':'♻️ Reiniciar VPS','security':'🛡️ Segurança','tools':'🛠 Ferramentas','people':'👥 Usuários registrados','message_users':'📢 Mensagem aos usuários','bans':'🚫 Banir usuário','domain':'🌐 Domínio','access_toggle':'🔐 Acesso','ref_renew':'🎁 Resgatar 7 dias (3 indicações)','create:normal':'👤 Conta normal','create:v2ray':'🚀 Conta V2Ray','backup:daily':'📅 Enviar diariamente','backup:7d':'7️⃣ A cada 7 dias','backup:15d':'1️⃣5️⃣ A cada 15 dias','backup:30d':'3️⃣0️⃣ A cada 30 dias','backup:once':'☝️ Uma vez','tool:firewall':'🔥 Firewall','tool:optimizar':'🚀 Otimizar','tool:ads':'🚫 Ads','tool:torrent':'🚫 Torrent','tool:speed':'📈 Speedtest','tool:scanner':'🔎 Scanner','tool:files':'📁 Arquivos','security:auto':'🛡️ Bloqueio SSH automático','quota_public':'👥 Público','quota_admin':'👨‍💼 Admin','ban_add':'🚫 Banir usuários','ban_remove':'🔓 Desbanir','ban_list':'📋 Lista de banidos'}
}
# Fill the remaining languages from English, replacing the most visible labels.
for _lg,_name in [('fr','Français'),('de','Deutsch'),('it','Italiano'),('ru','Русский'),('tr','Türkçe')]:
 BUTTONS[_lg]=dict(BUTTONS['en'])
BUTTONS['fr'].update({'users':'👤 Utilisateurs','referrals':'🔗 Parrainages','language':'🌐 Langue','info':'ℹ️ Informations','settings':'⚙️ Paramètres','home':'🔙 Accueil','create':'➕ Créer un compte','renew':'♻️ Renouveler','cancel':'❌ Annuler','monetization':'💰 Monétisation','system_update':'🔄 Mettre à jour le système','system_update_now':'⬇️ Mettre à jour maintenant','ref_renew':'♻️ Renouveler 24h (3 parrainages)'})
BUTTONS['de'].update({'users':'👤 Benutzer','referrals':'🔗 Empfehlungen','language':'🌐 Sprache','info':'ℹ️ Informationen','settings':'⚙️ Einstellungen','home':'🔙 Start','create':'➕ Konto erstellen','renew':'♻️ Verlängern','cancel':'❌ Abbrechen','monetization':'💰 Monetarisierung','system_update':'🔄 System aktualisieren','system_update_now':'⬇️ Jetzt aktualisieren','ref_renew':'♻️ 24h verlängern (3 Empfehlungen)'})
BUTTONS['it'].update({'users':'👤 Utenti','referrals':'🔗 Referral','language':'🌐 Lingua','info':'ℹ️ Informazioni','settings':'⚙️ Impostazioni','home':'🔙 Home','create':'➕ Crea account','renew':'♻️ Rinnova','cancel':'❌ Annulla','monetization':'💰 Monetizzazione','system_update':'🔄 Aggiorna sistema','system_update_now':'⬇️ Aggiorna ora','ref_renew':'♻️ Rinnova 24h (3 referral)'})
BUTTONS['ru'].update({'users':'👤 Пользователи','referrals':'🔗 Рефералы','language':'🌐 Язык','info':'ℹ️ Информация','settings':'⚙️ Настройки','home':'🔙 Главная','create':'➕ Создать аккаунт','renew':'♻️ Продлить','cancel':'❌ Отмена','monetization':'💰 Монетизация','system_update':'🔄 Обновить систему','system_update_now':'⬇️ Обновить сейчас','ref_renew':'♻️ Продлить 24ч (3 реферала)'})
BUTTONS['tr'].update({'users':'👤 Kullanıcılar','referrals':'🔗 Referanslar','language':'🌐 Dil','info':'ℹ️ Bilgi','settings':'⚙️ Ayarlar','home':'🔙 Ana sayfa','create':'➕ Hesap oluştur','renew':'♻️ Yenile','cancel':'❌ İptal','monetization':'💰 Para kazanma','system_update':'🔄 Sistemi güncelle','system_update_now':'⬇️ Şimdi güncelle','ref_renew':'♻️ 24 saat yenile (3 referans)'})
BUTTONS['zh']=dict(BUTTONS['en']); BUTTONS['zh'].update({'users':'👤 用户','referrals':'🔗 推荐','language':'🌐 语言','info':'ℹ️ 信息','settings':'⚙️ 设置','home':'🔙 首页','create':'➕ 创建账户','renew':'♻️ 续期','list':'📋 列表','online':'🟢 在线','account':'👤 账户','delete':'🗑️ 删除账户','cancel':'❌ 取消'})
BUTTONS['ja']=dict(BUTTONS['en']); BUTTONS['ja'].update({'users':'👤 ユーザー','referrals':'🔗 紹介','language':'🌐 言語','info':'ℹ️ 情報','settings':'⚙️ 設定','home':'🔙 ホーム','create':'➕ アカウント作成','renew':'♻️ 更新','list':'📋 一覧','online':'🟢 オンライン','account':'👤 アカウント','delete':'🗑️ 削除','cancel':'❌ キャンセル'})
BUTTONS['ko']=dict(BUTTONS['en']); BUTTONS['ko'].update({'users':'👤 사용자','referrals':'🔗 추천','language':'🌐 언어','info':'ℹ️ 정보','settings':'⚙️ 설정','home':'🔙 홈','create':'➕ 계정 생성','renew':'♻️ 갱신','list':'📋 목록','online':'🟢 온라인','account':'👤 계정','delete':'🗑️ 삭제','cancel':'❌ 취소'})
BUTTONS['id']=dict(BUTTONS['en']); BUTTONS['id'].update({'users':'👤 Pengguna','referrals':'🔗 Referensi','language':'🌐 Bahasa','info':'ℹ️ Informasi','settings':'⚙️ Pengaturan','home':'🔙 Beranda','create':'➕ Buat akun','renew':'♻️ Perpanjang','list':'📋 Daftar','online':'🟢 Online','account':'👤 Akun','delete':'🗑️ Hapus','cancel':'❌ Batal'})
BUTTONS['ar']=dict(BUTTONS['en']); BUTTONS['ar'].update({'users':'👤 المستخدمون','referrals':'🔗 الإحالات','language':'🌐 اللغة','info':'ℹ️ المعلومات','settings':'⚙️ الإعدادات','home':'🔙 الرئيسية','create':'➕ إنشاء حساب','renew':'♻️ تجديد','list':'📋 القائمة','online':'🟢 متصل','account':'👤 الحساب','delete':'🗑️ حذف','cancel':'❌ إلغاء'})

def localized_keyboard(uid,k):
 if not k:return k
 lg=lang(uid); out=[]
 for row in k:
  rr=[]
  for b in row:
   b=dict(b); cb=b.get('callback_data','')
   key=cb
   if cb.startswith('renew:'): key='renew'
   elif cb.startswith('proto:'): key=cb.split(':',1)[1]
   elif cb=='monetag_toggle': key='monetag_toggle_on' if 'Apagar' not in b.get('text','') and 'Disable' not in b.get('text','') else 'monetag_toggle_off'
   elif cb=='auto_update_toggle': key='auto_update_toggle_on' if 'Activar' in b.get('text','') or 'Enable' in b.get('text','') else 'auto_update_toggle_off'
   if key in BUTTONS.get(lg,{}): b['text']=BUTTONS[lg][key]
   elif cb.startswith('backup:'): b['text']=BUTTONS.get(lg,BUTTONS['en']).get(cb,BUTTONS['en'].get(cb,b.get('text','')))
   rr.append(b)
  out.append(rr)
 return out

def _track_message(c, result, kind='message'):
 try:
  mid=int(result.get('result',{}).get('message_id'))
  d=db(); arr=d.setdefault('chat_messages',{}).setdefault(str(c),[])
  arr.append({'id':mid,'ts':time.time(),'kind':kind})
  # Keep a bounded history in case the bot is very busy.
  d['chat_messages'][str(c)]=arr[-200:]
  save_db(d)
 except Exception as ex: log('TRACK MESSAGE '+repr(ex))
 return result

def delete_message(c,mid):
 try: api('deleteMessage',{'chat_id':c,'message_id':mid}); return True
 except Exception as ex: log('DELETE MESSAGE '+repr(ex)); return False

def clear_chat_messages(c, keep_latest=False, older_than=None):
 d=db();arr=d.get('chat_messages',{}).get(str(c),[])
 if not arr:return
 now=time.time();keep_id=None
 if keep_latest and arr: keep_id=arr[-1].get('id')
 remaining=[]
 for item in arr:
  mid=item.get('id');ts=float(item.get('ts',0) or 0)
  if not mid: continue
  should_delete=(mid!=keep_id) and (older_than is None or now-ts>=older_than)
  if should_delete:
   delete_message(c,mid)
  else:
   remaining.append(item)
 d.setdefault('chat_messages',{})[str(c)]=remaining
 save_db(d)

def schedule_config_cleanup(c):
 def w():
  time.sleep(600)
  try:
   # Monetag setup messages/documents are transient and are removed after 10 minutes.
   clear_chat_messages(c, keep_latest=False, older_than=0)
  except Exception as ex: log('CONFIG CLEANUP '+repr(ex))
 threading.Thread(target=w,daemon=True).start()

def send(c,t,k=None):
 d={'chat_id':c,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true'}
 if k:d['reply_markup']=json.dumps({'inline_keyboard':localized_keyboard(c,k)},ensure_ascii=False)
 return _track_message(c,api('sendMessage',d))
def send_document(c,path,caption=''):
 return _track_message(c,api_multipart('sendDocument',{'chat_id':str(c),'caption':caption,'parse_mode':'HTML'}, {'document':(Path(path).name,Path(path).read_bytes(),'text/html')}),'document')
def edit(c,m,t,k=None):
 try:return api('editMessageText',{'chat_id':c,'message_id':m,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true','reply_markup':json.dumps({'inline_keyboard':localized_keyboard(c,k)},ensure_ascii=False) if k is not None else json.dumps({'inline_keyboard':[]})})
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
def run_update(c=None,auto=False,key=None):
 updater=BASE/'update.sh'
 if not updater.exists():
  if c:send(c,'❌ No se encontró el actualizador del sistema.')
  return
 if c and not key:
  # The updater needs a license key. Ask once instead of leaving a Telegram
  # background job waiting forever on a terminal read().
  STATE[c]={'f':'system_update_key','s':'key','d':{}}
  return send(c,'🔐 <b>ACTUALIZACIÓN DEL SISTEMA</b>\n\nEscribe tu <b>Key de actualización</b> para continuar.\n\n⚠️ La clave se usará únicamente para validar y registrar esta actualización.',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
 cmd=f'bash {q(updater)} --telegram --key {q(key)}' if key else f'bash {q(updater)} --telegram'
 if c:
  bg(c,'Actualización del sistema',cmd,900,settings_keyboard(),restart_after=True)
 else:
  rc,_=sh(cmd,900)
  if rc==0:
   time.sleep(2)
   sh('systemctl restart kevintech-telegram.service',20)

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
  if rc==0:
   if title=='Actualización del sistema':
    final_ver=current_version()
    msg=f'🟢 <b>ACTUALIZACIÓN COMPLETADA</b>\n\n✅ <b>¡El sistema fue actualizado correctamente!</b>\n\n📦 Versión instalada: <code>{e(final_ver)}</code>\n🎉 Todos los archivos fueron aplicados correctamente.\n\n🔄 El bot continuará funcionando con la nueva versión.'
    send(c,msg,k)
   else:
    send(c,f'🟢 <b>{e(title)}</b>\n\n✅ Operación realizada correctamente.\n\n<pre>{e(out or "Proceso finalizado.")}</pre>',k)
   if restart_after:
    time.sleep(4)
    sh('systemctl restart kevintech-telegram.service',20)
  else:
   if title=='Actualización del sistema' and ('KEY_STATUS=USED' in out or 'La Key ya fue utilizada' in out):
    send(c,'🟠 <b>KEY YA UTILIZADA</b>\n\n❌ La Key de actualización que ingresaste ya fue utilizada anteriormente.\n\n🔑 Usa una Key nueva para realizar otra actualización.',k)
   else:
    send(c,f'🔴 <b>{e(title)}</b>\n\n❌ La operación no pudo completarse.\n\n<pre>{e(out or "Sin detalles del error.")}</pre>',k)
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
  d['users'][k]={'id':uid,'name':name or str(uid),'username':username or '','created':time.strftime('%F'),'started':False,'accounts':[],'v2ray_accounts':[],'language':'es','language_selected':False,'referrer':None,'referrals':[],'referral_renews':0,'history':[]}
  save_db(d)
 else:
  changed=False
  if name and d['users'][k].get('name')!=name:d['users'][k]['name']=name;changed=True
  if username is not None and d['users'][k].get('username','')!=username:d['users'][k]['username']=username;changed=True
  if 'v2ray_accounts' not in d['users'][k]:d['users'][k]['v2ray_accounts']=[];changed=True
  if 'history' not in d['users'][k]:d['users'][k]['history']=[];changed=True
  if changed:save_db(d)

def home(uid):
 b=BUTTONS.get(lang(uid),BUTTONS['es'])
 rows=[[{'text':b['users'],'callback_data':'users'},{'text':b['referrals'],'callback_data':'referrals'}],
       [{'text':b['language'],'callback_data':'language'},{'text':b['info'],'callback_data':'info'}]]
 if is_owner(uid):rows.append([{'text':b['settings'],'callback_data':'settings'}])
 return rows

def users_menu(uid):
 b=BUTTONS.get(lang(uid),BUTTONS['es'])
 rows=[[{'text':b['create'],'callback_data':'create'}],
       [{'text':b['list'],'callback_data':'list'},{'text':b['online'],'callback_data':'online'}],
       [{'text':b['account'],'callback_data':'account'},{'text':b['delete'],'callback_data':'delete'}]]
 # El botón Renovar manual es exclusivo del SUPER ADMIN.
 if is_owner(uid):
  rows.insert(0, [{'text':b['renew'],'callback_data':'renew'}])
 rows.append([{'text':b['home'],'callback_data':'home'}])
 return rows
USERS=users_menu

CREATE_MENU=[[{'text':'👤 Cuenta normal','callback_data':'create:normal'},{'text':'🚀 Cuenta V2Ray','callback_data':'create:v2ray'}],[{'text':'🔙 Usuarios','callback_data':'users'}]]
PROTO={'openssh':('OpenSSH','openssh.sh','ssh','22','1','5'),'dropbear':('Dropbear','dropbear.sh','dropbear','90,143,109','1','6'),'openvpn':('OpenVPN','openvpn.sh','openvpn','1194/UDP,2200/TCP,443/TCP','1','10'),'v2ray':('V2Ray/Xray','v2ray.sh','xray','443/TCP','1','13'),'checkuser':('CheckUser','checkuser.sh','checkuser','10016,10015,8888','1','8'),'slowdns':('SlowDNS','slowdns.sh','dnstt','5300/UDP','1','7'),'badvpn':('BadVPN','badvpn.sh','badvpn-7300','7300,7200','1','4'),'ssl':('SSL/WebSocket','ssl.sh','haproxy','80,443,8080,10015','1','6'),'udpcustom':('UDP Custom','udpcustom.sh','udp-custom','1-65535/UDP','1','7'),'zivpn':('ZiVPN','zivpn.sh','zivpn','20000-29999/UDP','1','10')}
PK=[[{'text':v[0],'callback_data':'proto:'+k}] for k,v in PROTO.items()]+[[{'text':'🔙 Inicio','callback_data':'home'}]]
SVCS={k:v[2] for k,v in PROTO.items()}
TOOLS=[[{'text':'🔥 Firewall','callback_data':'tool:firewall'},{'text':'🚀 Optimizar','callback_data':'tool:optimizar'}],[{'text':'🚫 Ads','callback_data':'tool:ads'},{'text':'🚫 Torrent','callback_data':'tool:torrent'}],[{'text':'📈 Speedtest','callback_data':'tool:speed'},{'text':'🔎 Scanner','callback_data':'tool:scanner'}],[{'text':'📁 Archivos','callback_data':'tool:files'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]

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
def userexists(u):
    # Accounts shown in the bot may be SSH users or V2Ray/VMess users.
    # Do not impose a stricter username regex than Linux/Xray itself; this
    # prevents "Lista" from showing an account that "Eliminar" rejects.
    u=str(u).strip()
    if not u or any(ch.isspace() for ch in u) or len(u)>64:
        return False
    if sh(f'getent passwd {q(u)} >/dev/null 2>&1',3)[0] == 0:
        return True
    try:
        d=db()
        return any(any(str(a).lower()==u.lower() for a in z.get('v2ray_accounts',[])) for z in d.get('users',{}).values())
    except Exception:
        return False


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

def referral_display(z,uid):
 username=str(z.get('username','')).strip()
 if username:return '@'+username
 return str(z.get('name','')).strip() or str(uid)

def referral_info(uid):
 d=db();u=d['users'].get(str(uid),{});refs=u.get('referrals',[])
 window=float(u.get('referral_window_start',0) or 0);used=int(u.get('referral_renews_used',0) or 0)
 if not window or time.time()-window>=86400:
  used=0
  if window:
   u['referral_window_start']=time.time();u['referral_renews_used']=0;save_db(d)
 remaining=max(0,3-used)
 link=f'https://t.me/{BOT_USERNAME}?start=ref_{uid}' if BOT_USERNAME else f'/start ref_{uid}'
 reset='Disponible nuevamente después de 24 horas.' if used>=3 else 'El contador se reinicia cada 24 horas.'
 return f'''🔗 <b>PROGRAMA DE REFERIDOS</b>\n\n👥 <b>Referidos: {len(refs)}</b>\n🎁 Renovaciones usadas en 24h: <b>{used}/3</b>\n⭐ Renovaciones disponibles: <b>{remaining}</b>\n\n🔗 <b>Tu enlace:</b>\n<code>{e(link)}</code>\n\n🎯 Necesitas <b>3 referidos</b> para activar el canje.\n♻️ Cada canje agrega <b>7 días</b> a la cuenta que elijas.\n⏱️ {reset}'''

def online_ssh():
 """Devuelve solo sesiones SSH que correspondan a cuentas reales del panel.
 Evita mostrar procesos/usuarios genéricos como `users` y reduce falsos positivos.
 """
 d=db()
 known=set()
 for z in d.get('users',{}).values():
  known.update(str(a).strip().lower() for a in z.get('accounts',[]) if a)
  known.update(str(a).strip().lower() for a in z.get('v2ray_accounts',[]) if a)
 if not known:
  return []
 out=subprocess.getoutput("ss -tnp state established 2>/dev/null || true")
 sessions=[]
 seen=set()
 for line in out.splitlines():
  parts=line.split()
  # En ss -tnp el destino local suele estar en la columna 3 y el peer en 4.
  if len(parts)<5 or not any(re.search(r':22$',x) for x in parts[3:5]):
   continue
  local=parts[3] if len(parts)>3 else ''
  peer=parts[4] if len(parts)>4 else '—'
  if not re.search(r':22(?:\]|$)',local):
   continue
  m=re.search(r'users:\(\("sshd",pid=(\d+)',line)
  pid=m.group(1) if m else ''
  if not pid:
   continue
  name=subprocess.getoutput(f"ps -o user= -p {q(pid)} 2>/dev/null").strip()
  if not name or name.lower() in ('root','sshd','users') or name.lower() not in known:
   continue
  ip=peer.rsplit(':',1)[0].strip('[]') if ':' in peer else peer
  key=(name.lower(),ip,pid)
  if key in seen: continue
  seen.add(key)
  sessions.append({'username':name,'ip':ip or '—','device':ip or '—','pid':pid})
 return sessions

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
  new=[x for x in clients if str(x.get('email','')).lower()!=str(username).lower()]
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
 if raw.startswith('/start adcompleted') or raw.startswith('/star adcompleted'):
  tok=raw.split('adcompleted',1)[1].strip().lstrip('_ ')
  return process_ad_completion(c,tok)
 if not me.get('language_selected'):
  STATE[c]={'f':'language','s':'pick','d':{}}
  return send(c,I18N['choose_lang']['es']+'\n\nSelecciona uno de los 13 idiomas disponibles:',language_keyboard(c))
 return send(c,tr(c,'home'),home(c))

def ad_configurations():
 d=db();m=d.get('monetization',{});items=[]
 try:
  v=m.get('monetag','')
  if v:
   z=json.loads(v)
   if z.get('enabled',True) and z.get('host_url'):items.append(('Monetag',z))
 except:pass
 return items

# La cantidad de anuncios usa una ROTACIÓN GLOBAL compartida por todas las
# acciones que requieren publicidad. Así, el siguiente proceso continúa desde
# donde quedó el anterior y no vuelve a empezar en 1 al cambiar de opción.
# Secuencia: 1 -> 4 -> 3 -> 3 -> 1 -> 4 -> 3 -> 4 -> 3 -> ...
AD_ROTATION=[1,4,3,3,1,4,3,4,3]

def next_ad_requirement(c,action,extra=None):
 d=db();rot=d.setdefault('ad_rotation',{})
 # Un único contador por usuario: crear, V2Ray, canjear y renovar comparten
 # la misma rueda de anuncios.
 idx=int(rot.get(str(c),0) or 0) % len(AD_ROTATION)
 required=int(AD_ROTATION[idx])
 rot[str(c)]=(idx+1)%len(AD_ROTATION)
 save_db(d)
 return required

def ad_count_for(action,extra=None):
 # Compatibilidad para instalaciones antiguas. La cantidad real se obtiene
 # siempre mediante next_ad_requirement().
 return 1

def ad_gate(c,action,extra=None):
 if is_owner(c):return False
 ads=ad_configurations()
 if not ads:return False
 required=next_ad_requirement(c,action,extra)
 pending=secrets.token_urlsafe(9)
 d=db();d.setdefault('ad_pending',{})[pending]={
  'uid':c,'action':action,'extra':extra or {},'remaining':required,
  'total':required,'expires':time.time()+3600
 };save_db(d)
 return send(c,f'💰 <b>PUBLICIDAD {required} PASOS</b>\n\nPara mantener el servicio gratuito, completa <b>{required} anuncios</b>.\n\nLa publicidad se renueva automáticamente en cada paso.',[[{'text':f'▶️ Ver anuncio 1/{required}','callback_data':'adopen:'+pending}]]) or True

def create_ad_token(c,action,extra=None,required=None):
 ads=ad_configurations()
 if not ads:return None
 selected=None
 for name,z in ads:
  if name.lower()=='':
   selected=(name,z);break
 if selected is None:selected=ads[0]
 name,conf=selected
 host=conf.get('host_url','').strip()
 if not host:return None
 token=secrets.token_urlsafe(24)
 d=db();d.setdefault('ad_tokens',{})[token]={
  'uid':c,'action':action,'extra':extra or {},'required':int(required or 1),'platform':name,
  'expires':time.time()+900
 };save_db(d)
 params={'token':token,'uid':c,'step':str(int(time.time()*1000)),'rotate':secrets.token_hex(4)}
 if name.lower()=='':
  params['blockId']=str(conf.get('block_id','')).strip()
 sep='&' if '?' in host else '?'
 return host+sep+urllib.parse.urlencode(params)+'#token='+urllib.parse.quote(token)

def consume_ad_token(c,token):
 d=db();item=d.get('ad_tokens',{}).get(token)
 if not item or int(item.get('uid',0))!=c or float(item.get('expires',0))<time.time():return None
 d['ad_tokens'].pop(token,None);save_db(d);return item

def start_create(c,kind,bypass_ads=False):
 if not bypass_ads and ad_gate(c,'create',{'kind':kind}):return
 STATE[c]={'f':'create','s':'u','d':{'kind':kind}}
 return send(c,'🚀 <b>CREAR CUENTA V2RAY</b>\n\nUsuario:' if kind=='v2ray' else '👤 <b>CREAR CUENTA</b>\n\nUsuario:')

def renew_now(c,username,days=None):
 try:
  if not userexists(username):
   return send(c,'❌ Esa cuenta ya no existe o ya fue eliminada.')
  if days is None:
   days=quota(c)[0]
  exp=subprocess.getoutput(f"date -d '+{int(days)} days' +%F")
  rc,o=sh(f'chage -E {q(exp)} {q(username)}',10)
  if rc!=0:
   return send(c,'🔴 <b>Error al renovar</b>\n<pre>'+e(o)+'</pre>')
  dat={'user':username,'days':int(days),'limit':quota(c)[1]}
  return send(c,account_message(c,dat,True))
 except Exception as ex:
  log('RENEW NOW '+repr(ex));return send(c,'🔴 No se pudo renovar la cuenta.')

def start_renew(c,username=None,bypass_ads=False,ad_action='renew'):
 if username:
  if not bypass_ads and ad_gate(c,ad_action,{'username':username}):return
  days=quota(c)[0]
  return renew_now(c,username,days)
 if not bypass_ads and ad_gate(c,'renew'):return
 STATE[c]={'f':'renew','s':'u','d':{}}
 return send(c,'♻️ <b>RENOVAR CUENTA</b>\n\nEscribe el usuario que deseas renovar:')

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
      text=f'⏳ <b>CUENTA PRÓXIMA A VENCER</b>\n\n👤 Cuenta: <code>{e(username)}</code>\n📅 Vencimiento: <b>{e(ex.strftime("%d/%m/%Y"))}</b>\n⏱️ Tiempo restante: <b>{"hoy" if left==0 else "1 día"}</b>\n\nPuedes renovarla desde el botón inferior.'
      k=[[{'text':'▶️ Ver anuncio y renovar','callback_data':'expiryrenew:'+username}]]
      try:send(owner,text,k)
      except:pass
      if owner!=OWNER:
       try:send(OWNER,f'🔔 <b>AVISO DE VENCIMIENTO</b>\n\n👤 Cuenta: <code>{e(username)}</code>\n📱 Propietario: <code>{e(mention)}</code>\n📅 Vence: <b>{e(ex.strftime("%d/%m/%Y"))}</b>',k)
       except:pass
   if changed:save_db(d)
  except Exception as ex:log('EXPIRY NOTICE '+repr(ex))
  time.sleep(1800)


USER_COMMANDS={
 'es':[('/cmds','Ver comandos disponibles'),('/crear','Crear cuenta'),('/renovar','Renovar cuenta'),('/lista','Ver mis cuentas'),('/online','Ver conexiones'),('/cuenta','Consultar cuenta'),('/eliminar','Eliminar cuenta'),('/referidos','Ver referidos'),('/idioma','Cambiar idioma'),('/informacion','Información'),('/me','Mi información e historial')],
 'en':[('/cmds','Show available commands'),('/create','Create account'),('/renew','Renew account'),('/list','View my accounts'),('/online','View connections'),('/account','Account information'),('/delete','Delete account'),('/referrals','View referrals'),('/language','Change language'),('/info','Information'),('/me','My information and history')],
 'pt':[('/cmds','Ver comandos disponíveis'),('/criar','Criar conta'),('/renovar','Renovar conta'),('/lista','Ver minhas contas'),('/online','Ver conexões'),('/conta','Consultar conta'),('/eliminar','Eliminar conta'),('/referidos','Ver indicações'),('/idioma','Alterar idioma'),('/informacao','Informações'),('/me','Minhas informações e histórico')],
 'fr':[('/cmds','Voir les commandes disponibles'),('/creer','Créer un compte'),('/renouveler','Renouveler le compte'),('/liste','Voir mes comptes'),('/online','Voir les connexions'),('/compte','Informations du compte'),('/supprimer','Supprimer le compte'),('/parrainages','Voir les parrainages'),('/langue','Changer la langue'),('/information','Informations'),('/me','Mes informations et historique')],
 'de':[('/cmds','Verfügbare Befehle'),('/erstellen','Konto erstellen'),('/erneuern','Konto verlängern'),('/liste','Meine Konten'),('/online','Verbindungen'),('/konto','Kontoinformationen'),('/loeschen','Konto löschen'),('/empfehlungen','Empfehlungen'),('/sprache','Sprache ändern'),('/info','Informationen'),('/me','Meine Informationen und Verlauf')],
 'it':[('/cmds','Comandi disponibili'),('/crea','Crea account'),('/rinnova','Rinnova account'),('/lista','I miei account'),('/online','Connessioni'),('/account','Informazioni account'),('/elimina','Elimina account'),('/referidos','Referral'),('/lingua','Cambia lingua'),('/informazioni','Informazioni'),('/me','Le mie informazioni e cronologia')],
 'ru':[('/cmds','Доступные команды'),('/create','Создать аккаунт'),('/renew','Продлить аккаунт'),('/list','Мои аккаунты'),('/online','Подключения'),('/account','Информация аккаунта'),('/delete','Удалить аккаунт'),('/referrals','Рефералы'),('/language','Язык'),('/info','Информация'),('/me','Моя информация и история')],
 'tr':[('/cmds','Kullanılabilir komutlar'),('/create','Hesap oluştur'),('/renew','Hesabı yenile'),('/list','Hesaplarım'),('/online','Bağlantılar'),('/account','Hesap bilgisi'),('/delete','Hesabı sil'),('/referrals','Referanslar'),('/language','Dil değiştir'),('/info','Bilgi'),('/me','Bilgilerim ve geçmişim')],
 'zh':[('/cmds','查看可用命令'),('/create','创建账户'),('/renew','续期账户'),('/list','我的账户'),('/online','在线连接'),('/account','账户信息'),('/delete','删除账户'),('/referrals','推荐计划'),('/language','切换语言'),('/info','系统信息'),('/me','我的信息和记录')],
 'ja':[('/cmds','利用可能なコマンド'),('/create','アカウント作成'),('/renew','アカウント更新'),('/list','自分のアカウント'),('/online','接続状況'),('/account','アカウント情報'),('/delete','アカウント削除'),('/referrals','紹介'),('/language','言語変更'),('/info','情報'),('/me','自分の情報と履歴')],
 'ko':[('/cmds','사용 가능한 명령'),('/create','계정 생성'),('/renew','계정 갱신'),('/list','내 계정'),('/online','연결 상태'),('/account','계정 정보'),('/delete','계정 삭제'),('/referrals','추천'),('/language','언어 변경'),('/info','정보'),('/me','내 정보 및 기록')],
 'id':[('/cmds','Lihat perintah'),('/create','Buat akun'),('/renew','Perpanjang akun'),('/list','Akun saya'),('/online','Koneksi aktif'),('/account','Info akun'),('/delete','Hapus akun'),('/referrals','Referensi'),('/language','Ganti bahasa'),('/info','Informasi'),('/me','Info dan riwayat saya')],
 'ar':[('/cmds','عرض الأوامر المتاحة'),('/create','إنشاء حساب'),('/renew','تجديد الحساب'),('/list','حساباتي'),('/online','الاتصالات'),('/account','معلومات الحساب'),('/delete','حذف الحساب'),('/referrals','الإحالات'),('/language','تغيير اللغة'),('/info','المعلومات'),('/me','معلوماتي وسجلي')],
}
def cmds_text(uid):
 rows=USER_COMMANDS.get(lang(uid),USER_COMMANDS['es'])
 return '📚 <b>CENTRO DE COMANDOS</b>\n\nAquí tienes las acciones disponibles para tu nivel de acceso.\n\n'+'\n'.join(f'• <code>{e(cmd)}</code> — {e(desc)}' for cmd,desc in rows)

def add_history(uid,action,detail=''):
 d=db(); z=d['users'].setdefault(str(uid),{}); h=z.setdefault('history',[])
 h.append({'date':time.strftime('%Y-%m-%d %H:%M:%S'),'action':action,'detail':str(detail)[:200]})
 if len(h)>100: del h[:-100]
 save_db(d)

I18N['choose_lang'].update({
 'zh':'🌎 <b>选择语言</b>\n\n请选择你要使用的语言。',
 'ja':'🌎 <b>言語を選択</b>\n\n使用する言語を選択してください。',
 'ko':'🌎 <b>언어 선택</b>\n\n사용할 언어를 선택하세요.',
 'id':'🌎 <b>Pilih bahasa</b>\n\nPilih bahasa yang ingin digunakan.',
 'ar':'🌎 <b>اختر لغتك</b>\n\nاختر اللغة التي تريد استخدامها.',
})
I18N['home'].update({
 'zh':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>主面板</b>\n\n通过 Telegram 快速管理账户。',
 'ja':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>メインパネル</b>\n\nTelegramからアカウントを簡単に管理できます。',
 'ko':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>메인 패널</b>\n\nTelegram에서 계정을 빠르게 관리하세요.',
 'id':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>PANEL UTAMA</b>\n\nKelola akun dengan cepat melalui Telegram.',
 'ar':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>اللوحة الرئيسية</b>\n\nأدر حساباتك بسرعة عبر Telegram.',
})
ME_I18N={
 'es':('👤 <b>MI INFORMACIÓN</b>','Nombre','Usuario','Idioma','Registro','Cuentas','Mis cuentas','Historial reciente','Sin actividad registrada todavía.'),
 'en':('👤 <b>MY INFORMATION</b>','Name','Username','Language','Registered','Accounts','My accounts','Recent history','No activity recorded yet.'),
 'pt':('👤 <b>MINHAS INFORMAÇÕES</b>','Nome','Usuário','Idioma','Registro','Contas','Minhas contas','Histórico recente','Nenhuma atividade registrada ainda.'),
 'fr':('👤 <b>MES INFORMATIONS</b>','Nom','Nom d’utilisateur','Langue','Inscription','Comptes','Mes comptes','Historique récent','Aucune activité enregistrée.'),
 'de':('👤 <b>MEINE INFORMATIONEN</b>','Name','Benutzername','Sprache','Registrierung','Konten','Meine Konten','Letzte Aktivitäten','Noch keine Aktivität.'),
 'it':('👤 <b>LE MIE INFORMAZIONI</b>','Nome','Nome utente','Lingua','Registrazione','Account','I miei account','Cronologia recente','Nessuna attività registrata.'),
 'ru':('👤 <b>МОЯ ИНФОРМАЦИЯ</b>','Имя','Имя пользователя','Язык','Регистрация','Аккаунты','Мои аккаунты','Последняя история','Активность пока не зарегистрирована.'),
 'tr':('👤 <b>BİLGİLERİM</b>','Ad','Kullanıcı adı','Dil','Kayıt','Hesaplar','Hesaplarım','Son geçmiş','Henüz etkinlik kaydı yok.'),
 'zh':('👤 <b>我的信息</b>','姓名','用户名','语言','注册','账户','我的账户','最近记录','暂无活动记录。'),
 'ja':('👤 <b>自分の情報</b>','名前','ユーザー名','言語','登録日','アカウント','自分のアカウント','最近の履歴','まだ活動記録はありません。'),
 'ko':('👤 <b>내 정보</b>','이름','사용자명','언어','가입일','계정','내 계정','최근 기록','아직 기록된 활동이 없습니다.'),
 'id':('👤 <b>INFORMASI SAYA</b>','Nama','Username','Bahasa','Terdaftar','Akun','Akun saya','Riwayat terbaru','Belum ada aktivitas.'),
 'ar':('👤 <b>معلوماتي</b>','الاسم','اسم المستخدم','اللغة','التسجيل','الحسابات','حساباتي','السجل الأخير','لا يوجد نشاط مسجل بعد.'),
}
def me_text(uid):
 d=db(); z=d['users'].get(str(uid),{}); L=ME_I18N.get(lang(uid),ME_I18N['es'])
 title,name_l,user_l,lang_l,reg_l,acc_l,myacc_l,hist_l,none=L
 name=z.get('name') or str(uid); uname=('@'+z.get('username')) if z.get('username') else '—'
 accounts=z.get('accounts',[]); hist=z.get('history',[])
 out=(f"{title}\n\n🆔 ID: <code>{uid}</code>\n👤 {name_l}: <b>{e(name)}</b>\n"
      f"🔗 {user_l}: <b>{e(uname)}</b>\n🌐 {lang_l}: <b>{e(lang(uid))}</b>\n"
      f"📅 {reg_l}: <b>{e(z.get('created','—'))}</b>\n👥 {acc_l}: <b>{len(accounts)}</b>")
 if accounts: out+=f"\n\n🔐 <b>{myacc_l}</b>\n"+'\n'.join('• <code>'+e(a)+'</code>' for a in accounts[:30])
 out+=f"\n\n🕘 <b>{hist_l}</b>"
 if hist:
  for h in hist[-10:][::-1]:
   out+=f'\n• <code>{e(h.get("date",""))}</code> — {e(h.get("action",""))}'+(f' — {e(h.get("detail",""))}' if h.get("detail") else '')
 else: out+=f"\n• {none}"
 return out

def process_text(c,t,chat_type=None):
 CHAT_TYPES[c]=chat_type or CHAT_TYPES.get(c,'private')
 d=db();uid=c
 if banned(uid):return send(c,'🚫 Tu acceso está bloqueado.')
 registered(uid)
 if t.startswith('/start') or t.startswith('/star'):return handle_start(c,t)
 # La configuración de Monetag deben procesarse antes que cualquier comando.
 # Esto permite pegar scripts largos o bloques que comienzan con '/'.
 st0=STATE.get(c)
 if st0 and st0.get('f') in ('monetag','domain','admin_add','admin_remove','admin_rename','ban_add','ban_remove','message_users','quota_public','quota_admin','system_update_key'):
  return admin_text(c,t)
 cmd=t.split()[0].lower() if t.split() else ''
 if cmd=='/cmds':
  return send(c,cmds_text(uid),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 if cmd=='/me':
  return send(c,me_text(uid),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 if cmd in ('/crear','/crearcuenta','/create','/criar','/creer','/erstellen','/crea','/creercompte','/criarconta','/hesapolustur','/zangmi'):
  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado. Abre el chat privado del bot.')
  if not allowed(uid):return send(c,'🔒 El bot está en modo privado.')
  return send(c,'➕ <b>CREAR CUENTA</b>\n\nSelecciona el tipo de cuenta:',CREATE_MENU)
 if cmd in ('/renovar','/renew','/renouveler','/erneuern','/rinnova','/renouvelercompte','/kontoerneuern','/yenile','/renewaccount'):
  return start_renew(c)
 if cmd in ('/lista','/cuentas','/list','/liste','/mescomptes','/hesaplarim','/akun'):
  return cb(c,0,c,0,'list')
 if cmd in ('/online','/conectados','/connections','/connexions','/verbindungen','/koneksi'):
  return cb(c,0,c,0,'online')
 if cmd in ('/cuenta','/info_cuenta','/account','/compte','/konto','/zhanghu','/akaunto','/gyejeong'):
  STATE[c]={'f':'account','s':'u','d':{}};return send(c,'👤 <b>CONSULTAR CUENTA</b>\n\nEscribe el usuario:')
 if cmd in ('/eliminar','/borrar','/delete','/supprimer','/loeschen','/elimina','/supprimercompte','/hapus','/del'):
  STATE[c]={'f':'delete','s':'u','d':{}};return send(c,'👤 <b>ELIMINAR CUENTA</b>\n\nEscribe el usuario:')
 if cmd in ('/referidos','/referrals','/parrainages','/empfehlungen'):
  rows=[[{'text':'🎁 Cangear 7 días','callback_data':'ref_renew'}]] if len(d['users'].get(str(c),{}).get('referrals',[]))>=3 else []
  rows.append([{'text':'🔙 Inicio','callback_data':'home'}])
  return send(c,referral_info(c),rows)
 if cmd in ('/idioma','/language','/langue','/sprache','/lingua','/lang','/sprachewechsel','/bahasa','/yuyan'):
  return send(c,I18N['choose_lang'].get(lang(c),I18N['choose_lang']['es']),language_keyboard(c))
 if cmd in ('/informacion','/info','/informacao','/information','/informasi','/thongtin'):
  return send(c,tr(c,'info'),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 if t.startswith('/referidos'):return send(c,referral_info(c))
 if not allowed(uid):return send(c,'🔒 El bot está en modo privado.')
 st=STATE.get(c)
 if not st:return None
 f,step,dat=st['f'],st['s'],st['d']
 if f=='ref_renew' and step=='u':
  username=t.strip()
  if not userexists(username):return send(c,'❌ Cuenta no encontrada.\n\nEstimado usuario, por favor escriba un usuario SSH válido para cangear.',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
  # Only allow the owner to redeem days on their own account.
  d=db();owner_row=d['users'].get(str(c),{})
  if username not in owner_row.get('accounts',[]):return send(c,'❌ Esa cuenta no pertenece a tu usuario de Telegram. Escribe una cuenta que sea tuya:',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
  dat['user']=username;st['s']='confirm'
  info=account_info(c,username)
  return send(c,'🎁 <b>DATOS PARA CANJEAR</b>\n\n'+info+'\n\n¿La información es correcta?\n\nAl confirmar se agregarán <b>7 días</b> a esta cuenta.',[[{'text':'✅ Sí, es correcto','callback_data':'ref_confirm'}],[{'text':'❌ Cancelar','callback_data':'cancel'}]])
 if f=='ref_renew' and step=='confirm':
  return send(c,'❌ Usa los botones para confirmar el canje.',[[{'text':'✅ Sí, es correcto','callback_data':'ref_confirm'}],[{'text':'❌ Cancelar','callback_data':'cancel'}]])
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
    maxdays,maxdev=quota(c);dat['days']=maxdays;dat['limit']=maxdev;return cb(c,0,c,0,'do:create')
   st['s']='p';return send(c,'🔑 Contraseña:')
  # Renovación: usa siempre la cuota configurada; no solicita días ni límite.
  maxdays,maxdev=quota(c);dat['days']=maxdays;dat['limit']=maxdev;return cb(c,0,c,0,'do:renew')
 if f=='create' and step=='p':
  dat['pass']=t
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
 admin_only=(x in ('settings','admins','admin_list','admin_add','admin_remove','admin_rename','bans','ban_add','ban_remove','ban_list','backup_restore','backup_menu','backup_now','restore','monetization','monetag','monetag_toggle','monetag_config','monetag_delete','quotas','quota_public','quota_admin','security','security:auto','tools','domain','people','message_users','restart_vps','system_update','system_update_now','auto_update_toggle','do_reboot') or x.startswith(('admin_','ban_','quota_','tool:','proto:','in:','un:','svc_restart:')))
 if admin_only and not is_owner(u): return ans(i,'Solo el SUPER ADMIN puede usar esta función.')
 if x.startswith('lang:'):
  language=x.split(':',1)[1];d['users'][str(u)]['language']=language;d['users'][str(u)]['language_selected']=True;save_db(d);STATE.pop(u,None);return edit(c,m,tr(u,'home'),home(u))
 if x.startswith('adopen:'):
  try:
   pending=x.split(':',1)[1];d=db();pd=d.get('ad_pending',{}).get(pending)
   if not pd or int(pd.get('uid',0))!=c or float(pd.get('expires',0))<time.time():raise ValueError('solicitud expirada')
   action=pd.get('action','');extra=pd.get('extra',{}) or {}
   if action not in ('create','renew','ref_renew','expiry_renew'):raise ValueError('acción inválida')
   d.get('ad_pending',{}).pop(pending,None);save_db(d)
   url=create_ad_token(c,action,extra,int(pd.get('total',1)))
   if not url:return ans(i,'Publicidad no configurada')
   n=int(pd.get('total',1));done=n-int(pd.get('remaining',n))+1
   return edit(c,m,f'💰 <b>ANUNCIO {done}/{n}</b>\n\nPulsa el botón para abrir la publicidad. Al terminar aparecerá automáticamente el siguiente.',[[{'text':f'▶️ Ver anuncio {done}/{n}','web_app':{'url':url}}],[{'text':'❌ Cancelar','callback_data':'cancel'}]])
  except Exception as ex:
   log('AD OPEN '+repr(ex));return ans(i,'No se pudo preparar el anuncio')
 if x=='ref_confirm':
  st=STATE.get(u)
  if not st or st.get('f')!='ref_renew' or st.get('s')!='confirm':return ans(i,'Solicitud de canje expirada')
  username=st.get('d',{}).get('user','');d=db();z=d['users'].get(str(u),{})
  if username not in z.get('accounts',[]):STATE.pop(u,None);return ans(i,'La cuenta ya no pertenece a tu usuario')
  # Solo el SUPER ADMIN queda exento. Usuarios y administradores deben
  # completar la publicidad antes de aplicar el canje.
  if is_owner(u):
   return apply_referral_reward(u,username)
  if ad_gate(u,'ref_renew',{'username':username,'days':7}):
   return True
  return apply_referral_reward(u,username)
 if x=='cancel':STATE.pop(c,None);return edit(c,m,tr(u,'home'),home(u))
 if x=='home':return edit(c,m,tr(u,'home'),home(u))
 if x=='info':return edit(c,m,tr(u,'info'),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 if x=='language':return edit(c,m,I18N['choose_lang'].get(lang(u),I18N['choose_lang']['es']),language_keyboard(u)+[[{'text':BUTTONS.get(lang(u),BUTTONS['es'])['home'],'callback_data':'home'}]])
 if x=='users':
  b=BUTTONS.get(lang(u),BUTTONS['es'])
  return edit(c,m,'👤 <b>GESTIÓN DE CUENTAS</b>\n\nDesde aquí puedes crear cuentas, consultar sus datos, revisar quién está conectado y eliminar accesos.\n\n🔐 Las acciones disponibles dependen de tu nivel de acceso.',users_menu(u))
 if x=='referrals':
  ref_count=len(d['users'].get(str(u),{}).get('referrals',[]))
  rows=[[{'text':'🎁 Cangear 7 días','callback_data':'ref_renew'}]] if ref_count>=3 else []
  rows.append([{'text':'🔙 Inicio','callback_data':'home'}])
  return edit(c,m,referral_info(u),rows)
 if x=='create':
  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado. Abre el chat privado del bot.')
  if not allowed(u):return send(c,'🔒 Acceso privado.')
  return edit(c,m,'➕ <b>CREAR CUENTA</b>\n\nSelecciona el tipo de cuenta:',CREATE_MENU)
 if x in ('create:normal','create:v2ray'):
  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado.')
  if not allowed(u):return send(c,'🔒 Acceso privado.')
  kind='v2ray' if x.endswith('v2ray') else 'normal'
  return start_create(c,kind)
 if x=='renew':
  if not is_owner(u):return ans(i,'Solo el SUPER ADMIN puede renovar manualmente.')
  return start_renew(c)
 if x.startswith('expiryrenew:'):
  username=x.split(':',1)[1]
  if not userexists(username):return send(c,'❌ Esa cuenta ya no existe.')
  return start_renew(c,username,False,'expiry_renew')
 if x.startswith('renew:'):
  username=x.split(':',1)[1]
  if not userexists(username):return send(c,'❌ Esa cuenta ya no existe.')
  return start_renew(c,username)
 if x=='account':STATE[c]={'f':'account','s':'u','d':{}};return send(c,'👤 <b>CUENTA</b>\n\nEscribe tu usuario para consultar la información:')
 if x=='delete':STATE[c]={'f':'delete','s':'u','d':{}};return send(c,'🗑️ <b>ELIMINAR CUENTA</b>\n\nEscribe el usuario:')
 if x=='list':
  if is_owner(u):
   lines=[];total=0
   for sid,z in d['users'].items():
    mention='@'+str(z.get('username')) if z.get('username') else sid
    ac=z.get('accounts',[]);total+=len(ac)
    lines.append(f'👤 <b>{e(mention)}</b>\n'+('\n'.join(f'   • <code>{e(a)}</code> — 🔑 xxx' for a in ac) if ac else '   • Sin cuentas'))
   text='📋 <b>TODAS LAS CUENTAS</b>\n\n👥 Propietarios: <b>'+str(len(d['users']))+'</b>\n🔐 Cuentas creadas: <b>'+str(total)+'</b>\n\n'+'\n\n'.join(lines)
  else:
   z=d['users'].get(str(u),{});ac=z.get('accounts',[])
   text='📋 <b>TUS CUENTAS</b>\n\n'+('\n'.join('• <code>'+e(a)+'</code>' for a in ac) if ac else 'No tienes cuentas creadas todavía.')
  return edit(c,m,text)
 if x=='online':
  sessions=online_ssh();owners={}
  for sid,z in d['users'].items():
   for acc in z.get('accounts',[]): owners.setdefault(acc,[]).append((sid,z))
  visible=owners if is_owner(u) else {a:v for a,v in owners.items() if any(str(sid)==str(u) for sid,_ in v)}
  connected={}
  for s in sessions: connected.setdefault(s['username'],[]).append(s)
  rows=[]
  for acc in visible:
   live=connected.get(acc,[])
   if live:
    ips=', '.join(e(x['ip']) for x in live)
    rows.append(f'🟢 <b>{e(acc)}</b> — <b>{len(live)}</b>\n   🌐 {ips}')
   else: rows.append(f'⚪ <b>{e(acc)}</b> — <b>0</b>')
  total=sum(len(connected.get(a,[])) for a in visible)
  scope='Todas las cuentas' if is_owner(u) else 'Tus cuentas'
  text=f'🟢 <b>CUENTAS CONECTADAS</b>\n\n👥 {scope}\n📡 Conexiones activas: <b>{total}</b>\n\n'
  text+='\n'.join(rows) if rows else 'No hay cuentas registradas todavía.'
  if is_owner(u): text+='\n\n👑 <i>Super Admin: se muestran todas las cuentas registradas y sus conexiones activas.</i>'
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
      try:
       mention=("@"+urow.get("username")) if urow.get("username") else urow.get("name",str(c))
       send(int(ref),f'🎉 <b>¡Felicidades!</b>\nEl usuario {e(mention)} ha creado su primera cuenta.\n¡Has ganado <b>1 referido</b>!\nUsa el menú de referidos para canjearlo.')
      except:pass
     save_db(d)
     add_history(c,'Cuenta creada',dat['user']+' (V2Ray)');return send(c,v2ray_account_message(c,dat))
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
      uname=d['users'][str(c)].get('username') or '';mention=f'@{uname}' if uname else d['users'][str(c)].get('name','Usuario')
      try:send(int(ref),f'🎉 <b>¡Felicidades!</b>\nEl {e(mention)} ha creado su primera cuenta.\n¡Has ganado <b>1 referido</b>!\nUsa el menú de referidos para canjearlo.')
      except Exception as er:log('REF NOTIFY '+repr(er))
    else:save_db(d)
    return send(c,account_message(c,dat))
   return send(c,'🔴 <b>Error al crear</b>\n<pre>'+e(o)+'</pre>')
  if x=='do:renew':
   rc,o=sh(f'chage -E {q(exp)} {q(u0)}',10)
   if rc==0:add_history(c,'Cuenta renovada',u0)
   return send(c,account_message(c,dat,True)) if rc==0 else send(c,'🔴 <b>Error al renovar</b>\n<pre>'+e(o)+'</pre>')
 if x=='ref_renew':
  d=db();z=d['users'][str(u)]
  if len(z.get('referrals',[]))<3:return send(c,f'❌ Necesitas 3 referidos para cangear. Te faltan <b>{3-len(z.get("referrals",[]))}</b>.')
  if is_admin(u):
   pass
  else:
   window=float(z.get('referral_window_start',0) or 0);used=int(z.get('referral_renews_used',0) or 0)
   if not window or time.time()-window>=86400:
    window=time.time();used=0;z['referral_window_start']=window;z['referral_renews_used']=0;save_db(d)
   if used>=3:return send(c,'❌ Ya utilizaste los 3 canjes de este período. Podrás usar otros después de 24 horas.')
  STATE[u]={'f':'ref_renew','s':'u','d':{}};return send(c,'🎁 <b>CANJEAR 7 DÍAS</b>\n\nEstimado usuario, por favor escriba el <b>usuario de su cuenta</b> para cangear.\n\nDespués te mostraré la información para confirmar que sea correcta.',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
 if x=='userop:delete':
  st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.')
  u0=st['d']['user'];d=db();isv=any(any(str(a).lower()==u0.lower() for a in z.get('v2ray_accounts',[])) for z in d['users'].values())
  if isv:
   rc,o=delete_v2ray(u0)
  else:
   rc,o=sh(f'pkill -u {q(u0)} 2>/dev/null || true; userdel -r -f {q(u0)}',15)
  if rc==0:
   for z in d['users'].values():
    z['accounts']=[a for a in z.get('accounts',[]) if str(a).lower()!=u0.lower()];z['v2ray_accounts']=[a for a in z.get('v2ray_accounts',[]) if str(a).lower()!=u0.lower()];
    for ak in list(z.get('v2ray_expirations',{})):
     if str(ak).lower()==u0.lower():z['v2ray_expirations'].pop(ak,None)
   save_db(d)
  if rc==0:add_history(c,'Cuenta eliminada',u0)
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
 if x=='bans':return edit(c,m,'🚫 <b>CONTROL DE ACCESO</b>\n\nBloquea, desbloquea o consulta usuarios con acceso restringido al bot.',BAN_MENU)
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
 if x=='monetization':return edit(c,m,'💰 <b>MONETIZACIÓN</b>\n\nConfigura la plataforma de anuncios que utilizará el bot para mantener el servicio gratuito.',MONETIZATION)
 if x=='monetag':return monetag_menu(c,m)
 if x=='monetag_config':STATE[c]={'f':'monetag','s':'zone','d':{}};return send(c,"💰 <b>MONETAG — PASO 1</b>\n\nEscribe únicamente tu <b>ID de zona</b> de Monetag.\n\nEjemplo: <code>11217882</code>",[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
 if x=='monetag_delete':
  d['monetization']['monetag']='';save_db(d);return monetag_menu(c,m)
 if x=='monetag_toggle':
  v=d.get('monetization',{}).get('monetag','')
  if not v:return monetag_menu(c,m)
  try:z=json.loads(v)
  except:z={'sdk':v,'reward':'','url':f'https://t.me/{BOT_USERNAME}?start=adcompleted'}
  z['enabled']=not bool(z.get('enabled',True));d['monetization']['monetag']=json.dumps(z,ensure_ascii=False);save_db(d);return monetag_menu(c,m)
 if x=='':return _menu(c,m)
 if x=='_config':STATE[c]={'f':'','s':'blockid','d':{}};return send(c,'📱 <b> — PASO 1</b>\n\nEscribe únicamente tu <b>Block ID</b> de .\n\nEjemplo: <code>36350</code>',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
 if x=='_toggle':
   v=d.get('monetization',{}).get('','')
   if not v:return _menu(c,m)
   try:z=json.loads(v)
   except:z={'block_id':v,'enabled':True}
   z['enabled']=not bool(z.get('enabled',True));d['monetization']['']=json.dumps(z,ensure_ascii=False);save_db(d);return _menu(c,m)
 if x=='restart_vps':return send(c,'♻️ ¿Reiniciar el VPS ahora?',[[{'text':'✅ REINICIAR VPS','callback_data':'do_reboot'},{'text':'❌ CANCELAR','callback_data':'settings'}]])
 if x=='people':
  total=sum(1 for z in d['users'].values() if z.get('started'))
  return edit(c,m,f'👥 <b>PERSONAS REGISTRADAS</b>\n\nUsuarios con /start: <b>{total}</b>\n🔐 Cuentas creadas: <b>{sum(len(z.get("accounts",[])) for z in d["users"].values())}</b>\n🟢 Conexiones SSH activas: <b>{len(online_ssh())}</b>\n\nResumen general del bot.',settings_keyboard())
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
 if x=='tools':return edit(c,m,'🛠 <b>HERRAMIENTAS DEL VPS</b>\n\nUtilidades de mantenimiento, rendimiento, seguridad y diagnóstico.',TOOLS)
 if x.startswith('tool:'):
  if not is_owner(u):return ans(i,'Solo el super admin')
  k=x.split(':')[1];mp={'optimizar':'optimizar.sh','ads':'blockads.sh','torrent':'blocktorrent.sh','speed':'speedtest.sh','scanner':'scanner.sh',}
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
 qx=d['quotas'];return f'''📅 <b>CUOTAS Y LÍMITES</b>\n\n👥 Público: <b>{qx["public_days"]} días</b> · <b>{qx["public_devices"]} dispositivos/IP</b>\n👨‍💼 Administradores: <b>{qx["admin_days"]} días</b> · <b>{qx["admin_devices"]} dispositivos/IP</b>\n🚀 V2Ray: utiliza automáticamente la cuota pública.\n\n👑 El Super Admin puede ajustar estos valores desde este menú.'''

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
MONETIZATION=[[{'text':'💰 Monetag','callback_data':'monetag'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]

def settings_keyboard():
 d=db()
 access='🔐 Acceso: PÚBLICO 🟢' if d.get('access')=='public' else '🔐 Acceso: PRIVADO 🔴'
 return [[{'text':access,'callback_data':'access_toggle'}], *SETTINGS[1:]]

def monetag_menu(c,m=0):
 d=db();v=d.get('monetization',{}).get('monetag','');configured=bool(v);enabled=True
 if configured:
  try:enabled=bool(json.loads(v).get('enabled',True))
  except:pass
 text='💰 <b>MONETAG</b>\n\nEstado: <b>'+('🟢 ENCENDIDO' if enabled else '⛔ APAGADO')+'</b>' if configured else '💰 <b>MONETAG</b>\n\nEstado: <b>🔴 NO CONFIGURADO</b>'
 if configured:
  try:text+='\n\n🌐 URL: <code>'+e(json.loads(v).get('url',''))+'</code>'
  except:pass
  k=[[{'text':'⛔ Apagar' if enabled else '🟢 Encender','callback_data':'monetag_toggle'}],[{'text':'⚙️ Reconfigurar','callback_data':'monetag_config'},{'text':'🗑️ Eliminar','callback_data':'monetag_delete'}]]
 else:k=[[{'text':'⚙️ Configurar','callback_data':'monetag_config'}]]
 k.append([{'text':'🔙 Monetización','callback_data':'monetization'}]);return edit(c,m,text,k) if m else send(c,text,k)
def _menu(c,m=0):
 v=db().get('monetization',{}).get('','')
 configured=bool(v);enabled=True;block_id=''
 if configured:
  try:
   z=json.loads(v);enabled=bool(z.get('enabled',True));block_id=str(z.get('block_id',''))
  except:block_id=str(v)
 text='📱 <b></b>\\n\\nEstado: <b>'+('🟢 ENCENDIDO' if configured and enabled else '⛔ APAGADO')+'</b>' if configured else '📱 <b></b>\\n\\nEstado: <b>🔴 NO CONFIGURADO</b>'
 if configured and block_id:text+='\\n\\n🆔 Block ID: <code>'+e(block_id)+'</code>'
 k=[[{'text':'⛔ Apagar' if enabled else '🟢 Encender','callback_data':'_toggle'},{'text':'⚙️ Reconfigurar','callback_data':'_config'}]] if configured else [[{'text':'⚙️ Configurar','callback_data':'_config'}]]
 k.append([{'text':'🔙 Monetización','callback_data':'monetization'}]);return edit(c,m,text,k) if m else send(c,text,k)

def _script_markup(code):
 if not code:return ''
 code=str(code).strip()
 if '<script' in code.lower():return code
 return '<script>\n'+code+'\n</script>'

def generate_monetag_html(uid,dat):
 template=TD/'monetization.html'
 if not template.exists():
  template.write_text(DEFAULT_MONETIZATION_HTML,encoding='utf-8');os.chmod(template,0o600)
 html=template.read_text(encoding='utf-8')
 bot_url=dat.get('url','').strip() or (f'https://t.me/{BOT_USERNAME}' if BOT_USERNAME else '')
 zone=str(dat.get('zone','')).strip()
 if not zone:
  # Compatibility with an older saved configuration: recover the zone from the
  # old SDK instead of asking the administrator for SDK/config again.
  old=str(dat.get('sdk','')).strip()
  m=re.search(r'data-zone=[\"\'](\d+)[\"\']',old,re.I)
  zone=m.group(1) if m else '11217882'
 # IMPORTANT: keep the original HTML structure and the original script position.
 # Only replace the zone identifier and its related show_<zone> references.
 if zone:
  html=re.sub(r'data-zone=[\"\']\d+[\"\']',f'data-zone=\"{zone}\"',html,flags=re.I)
  html=re.sub(r'data-sdk=[\"\']show_\d+[\"\']',f'data-sdk=\"show_{zone}\"',html,flags=re.I)
  html=re.sub(r'\bshow_\d+\b',f'show_{zone}',html)
  # Also replace the old literal zone wherever it is referenced by the template.
  html=html.replace('11217882',zone)
 # Replace any hard-coded Telegram bot deep link in the template.
 if bot_url:
  html=re.sub(r'https://t\.me/[A-Za-z0-9_]+\?start=adcompleted',bot_url.rstrip('/')+'?start=adcompleted',html)
 # The current template already loads Monetag in <head>. Do not inject or move it.
 # The placeholders remain for compatibility, but no SDK/reward code is requested.
 html=html.replace('__BOT_URL_JSON__',json.dumps(bot_url)).replace('__SDK_CODE_JSON__',json.dumps('')).replace('__REWARD_CODE_JSON__',json.dumps(''))
 # Keep the page's existing ad call, but make its function name match the configured zone.
 html=html.replace('https://t.me/sshprivanoxbot?start=adcompleted',bot_url.rstrip('/')+'?start=adcompleted')
 fn=BACK/'monetization.html';html=html.replace('https://t.me/sshprivanoxbot?start=adcompleted',bot_url.rstrip('/')+'?start=adcompleted')
 fn.write_text(html,encoding='utf-8');os.chmod(fn,0o600);return fn


def generate__html(uid,dat):
 template=TD/'.html'
 if not template.exists():raise FileNotFoundError('No existe .html')
 html=template.read_text(encoding='utf-8')
 block_id=str(dat.get('block_id','')).strip()
 bot_url=dat.get('url','').strip() or (f'https://t.me/{BOT_USERNAME}' if BOT_USERNAME else '')
 if not block_id or not block_id.isdigit():raise ValueError('Block ID de  inválido')
 if not bot_url:raise ValueError('URL del bot no configurada')
 html=html.replace('__BOT_URL_JSON__',json.dumps(bot_url))
 html=re.sub(
  r'(const\\s+blockId\\s*=\\s*params\\.get\\(["\\\']blockId["\\\']\\)\\s*\\|\\|\\s*)["\\\']\\d+["\\\']',
  lambda m:m.group(1)+json.dumps(block_id),html
 )
 # Preserve the source HTML structure/content; only fill configuration data.
 fn=BACK/'.html';fn.write_text(html,encoding='utf-8');os.chmod(fn,0o600);return fn

def admin_text(c,t):
 st=STATE.get(c);d=db();f=st['f'];step=st['s'];dat=st['d']
 if f=='monetag':
  # Remove the previous setup prompt/document before moving to the next step.
  clear_chat_messages(c, keep_latest=False, older_than=0)
 if f=='system_update_key' and step=='key':
  key=t.strip()
  if not key:return send(c,'❌ La Key no puede estar vacía.',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
  STATE.pop(c,None)
  return run_update(c,False,key)
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
 if f=='monetag' and step=='zone':
  val=t.strip()
  if not val.isdigit() or int(val)<1:return send(c,'❌ ID de zona inválido. Escribe únicamente números, por ejemplo <code>11217882</code>.')
  dat['zone']=val;st['s']='boturl';return send(c,'✅ <b>ID de zona guardado.</b>\n\n🌐 <b>Paso 2:</b> Ingresa la URL de tu bot.\nEjemplo: <code>https://t.me/tu_bot</code>',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
 if f=='monetag' and step=='boturl':
  dat['url']=t.strip()
  fn=generate_monetag_html(c,dat)
  send(c,'📄 <b>monetization.html listo</b>\n\nSe generó conservando la posición original del script de Monetag en el <code>&lt;head&gt;</code>. Solo se cambiaron los identificadores de zona relacionados con tu ID.')
  send_document(c,fn,'📄 monetization.html — archivo generado automáticamente.')
  st['s']='hosturl'
  return send(c,'🌐 <b>Paso 3:</b> Ahora envía la <b>URL pública final</b> donde alojarás <code>monetization.html</code>.\n\nEjemplo: <code>https://tu-dominio.com/monetization.html</code>',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])
 if f=='monetag' and step=='hosturl':
  dat['host_url']=t.strip();dat['enabled']=True;d['monetization']['monetag']=json.dumps(dat,ensure_ascii=False);save_db(d);STATE.pop(c,None)
  schedule_config_cleanup(c)
  return send(c,'🟢 <b>Monetag configurado correctamente.</b>\n\n📌 ID de zona: <code>'+e(dat['zone'])+'</code>\n🌐 URL guardada: <code>'+e(dat['host_url'])+'</code>\n\n🧹 Los mensajes de configuración se eliminarán automáticamente después de 10 minutos.')
 if f=='' and step=='blockid':
  val=t.strip()
  if not val.isdigit() or int(val)<1:return send(c,'❌ <b>Block ID inválido.</b>\n\nEscribe únicamente números, por ejemplo <code>36350</code>.')
  dat['block_id']=val;st['s']='boturl'
  return send(c,'✅ <b>Block ID guardado.</b>\n\n🌐 <b>Paso 2:</b> Ingresa la URL de tu bot.\nEjemplo: <code>https://t.me/tu_bot</code>',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])

 if f=='' and step=='boturl':
  val=t.strip()
  if not re.match(r'^https?://t\.me/[A-Za-z0-9_]+/?$',val):return send(c,'❌ <b>URL del bot inválida.</b>\n\nUsa: <code>https://t.me/tu_bot</code>')
  dat['url']=val.rstrip('/')
  try:fn=generate__html(c,dat)
  except Exception as ex:
   log(' HTML '+repr(ex));return send(c,'❌ No se pudo generar .html.')
  send(c,'📄 <b>.html listo</b>\n\nSe generó con tu Block ID y la URL de tu bot.')
  send_document(c,fn,'📄 .html — archivo generado automáticamente.')
  st['s']='hosturl'
  return send(c,'🌐 <b>Paso 3:</b> Ahora envía la <b>URL pública final</b> donde alojarás <code>.html</code>.\n\nEjemplo: <code>https://tu-dominio.com/.html</code>',[[{'text':'❌ Cancelar','callback_data':'cancel'}]])

 if f=='' and step=='hosturl':
  val=t.strip().rstrip('/')
  if not re.match(r'^https?://',val):return send(c,'❌ <b>URL inválida.</b>\n\nEnvía la URL pública completa de <code>.html</code>.')
  dat['host_url']=val;dat['enabled']=True
  d['monetization']['']=json.dumps(dat,ensure_ascii=False);save_db(d);STATE.pop(c,None)
  schedule_config_cleanup(c)
  return send(c,'🟢 <b> configurado correctamente.</b>\n\n📌 Block ID: <code>'+e(dat['block_id'])+'</code>\n🤖 Bot: <code>'+e(dat['url'])+'</code>\n🌐 URL guardada: <code>'+e(dat['host_url'])+'</code>',MONETIZATION)

 if f=='domain' and step=='value':
  val=t.strip();cfg=BASE/'config.conf';lines=cfg.read_text(errors='ignore').splitlines() if cfg.exists() else [];found=False
  for i,l in enumerate(lines):
   if l.startswith('SERVER_DOMAIN='):lines[i]=f'SERVER_DOMAIN="{val}"';found=True
  if not found:lines.append(f'SERVER_DOMAIN="{val}"')
  cfg.write_text('\n'.join(lines)+'\n');STATE.pop(c,None);return send(c,'🟢 Dominio actualizado.',settings_keyboard())
 if f in ('quota_public','quota_admin','system_update_key'):
  key='public' if f=='quota_public' else 'admin'
  if step=='days':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Días inválidos.')
   dat['days']=int(t);st['s']='devices';return send(c,'📱 Máximo de dispositivos/IP:')
  if step=='devices':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Número inválido.')
   d['quotas'][key+'_days']=dat['days'];d['quotas'][key+'_devices']=int(t);save_db(d);STATE.pop(c,None);return send(c,'🟢 Cuota actualizada.',QUOTA)

_original_process=process_text
def restore_document(c,msg):
 if not is_owner(c):return
 doc=msg.get('document',{});name=doc.get('file_name','')
 st=STATE.get(c)
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

def message_cleanup_scheduler():
 while True:
  try:
   d=db();now=time.time()
   for token,item in list(d.get('ad_completed',{}).items()):
    try:
     if float(item.get('expires',0))<now:d['ad_completed'].pop(token,None)
    except: d['ad_completed'].pop(token,None)
   for token,item in list(d.get('ad_tokens',{}).items()):
    try:
     if float(item.get('expires',0))<now:d['ad_tokens'].pop(token,None)
    except: d['ad_tokens'].pop(token,None)
   for chat,arr in list(d.get('chat_messages',{}).items()):
    if len(arr)<=1:continue
    # After 24h remove old bot messages but always preserve the latest bot message.
    latest_id=arr[-1].get('id')
    kept=[]
    for item in arr:
     mid=item.get('id');ts=float(item.get('ts',0) or 0)
     if mid==latest_id or now-ts<86400:
      kept.append(item)
     else:
      delete_message(int(chat),int(mid))
    d['chat_messages'][chat]=kept
   save_db(d)
  except Exception as ex:log('MESSAGE CLEANUP '+repr(ex))
  time.sleep(1800)

def apply_referral_reward(c,username):
 try:
  d=db();z=d['users'].get(str(c),{});refs=z.get('referrals',[])
  if len(refs)<3:return send(c,f'❌ Necesitas 3 referidos para cangear. Te faltan <b>{3-len(refs)}</b>.')
  if not is_admin(c):
   window=float(z.get('referral_window_start',0) or 0);used=int(z.get('referral_renews_used',0) or 0)
   if not window or time.time()-window>=86400:window=time.time();used=0
   if used>=3:return send(c,'❌ Ya utilizaste los 3 canjes de este período.')
  else:window=time.time();used=0
  exp=subprocess.getoutput(f"date -d '+7 days' +%F")
  rc,o=sh(f'chage -E {q(exp)} {q(username)}',10)
  if rc!=0:return send(c,'🔴 <b>No se pudo aplicar el canje</b>\n<pre>'+e(o)+'</pre>')
  if not is_admin(c):z['referral_window_start']=window;z['referral_renews_used']=used+1
  save_db(d);STATE.pop(c,None)
  return send(c,account_message(c,{'user':username,'days':7,'limit':quota(c)[1]},True),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 except Exception as ex:
  log('REF REWARD '+repr(ex));return send(c,'🔴 No se pudo completar el canje.')

def process_ad_completion(c, token):
 try:
  token=str(token or '').strip();item=consume_ad_token(c,token)
  if not item:
   d=db();done=d.setdefault('ad_completed',{}).get(token)
   if done and int(done.get('uid',0))==c and float(done.get('expires',0))>=time.time():return True
   send(c,'❌ Este enlace de publicidad expiró o ya fue utilizado.');return False
  d=db();d.setdefault('ad_completed',{})[token]={'uid':c,'expires':time.time()+120}
  action=item.get('action');extra=item.get('extra',{}) or {}
  required=int(item.get('required') or ad_count_for(action,extra))
  seq_key=f"{c}:{action}:{extra.get('username','')}:{extra.get('kind','')}"
  seq=d.setdefault('ad_sequences',{}).get(seq_key)
  if not seq:
   seq={'remaining':required-1,'total':required,'expires':time.time()+3600}
   d['ad_sequences'][seq_key]=seq
  remaining=int(seq.get('remaining',0))
  if remaining>0:
   done=required-remaining
   seq['remaining']=remaining-1
   next_token=secrets.token_urlsafe(9)
   d.setdefault('ad_pending',{})[next_token]={'uid':c,'action':action,'extra':extra,'remaining':remaining,'total':required,'expires':time.time()+3600}
   save_db(d)
   send(c,f'💰 <b>ANUNCIO {done}/{required} COMPLETADO</b>\n\nContinúa con el siguiente anuncio.',[[{'text':f'▶️ Ver anuncio {done+1}/{required}','callback_data':'adopen:'+next_token}],[{'text':'❌ Cancelar','callback_data':'cancel'}]])
   return True
  d['ad_sequences'].pop(seq_key,None);save_db(d)
  if action=='create':return bool(start_create(c,extra.get('kind','normal'),True))
  if action in ('renew','expiry_renew'):
   return bool(renew_now(c,extra.get('username'),quota(c)[0] if not is_owner(c) else None) if extra.get('username') else start_renew(c,bypass_ads=True))
  if action=='ref_renew':return bool(apply_referral_reward(c,extra.get('username')))
 except Exception as ex:
  log('AD COMPLETE '+repr(ex));send(c,'❌ No se pudo completar la publicidad.');return False

def handle_webapp_data(c,msg):
 try:
  raw=msg.get('web_app_data',{}).get('data','')
  z=json.loads(raw)
  if z.get('type')=='adcompleted': return process_ad_completion(c,z.get('token',''))
 except Exception as ex:
  log('WEB APP DATA '+repr(ex))
 return False

def main():
 global BOT_USERNAME
 env();load_db();LOG.parent.mkdir(parents=True,exist_ok=True);LOG.touch();LOG.chmod(0o600);api('deleteWebhook',{'drop_pending_updates':'false'})
 try:BOT_USERNAME=api('getMe')['result'].get('username','')
 except:BOT_USERNAME=''
 threading.Thread(target=backup_scheduler,daemon=True).start()
 threading.Thread(target=message_cleanup_scheduler,daemon=True).start()
 threading.Thread(target=security_monitor,daemon=True).start()
 threading.Thread(target=v2ray_expiration_monitor,daemon=True).start();threading.Thread(target=near_expiry_notifications,daemon=True).start();threading.Thread(target=auto_update_monitor,daemon=True).start()
 off=int(OFF.read_text()) if OFF.exists() and OFF.read_text().strip().isdigit() else 0;log('BOT ONLINE')
 while True:
  try:
   r=api('getUpdates',{'offset':off,'timeout':30,'allowed_updates':json.dumps(['message','callback_query'])})
   for u in r.get('result',[]):
    off=u['update_id']+1;OFF.write_text(str(off))
    try:
     if 'callback_query' in u:
      z=u['callback_query'];m=z['message'];sender=z.get('from',{}) or {};registered(sender.get('id',m['chat']['id']), sender.get('first_name') or sender.get('last_name') or str(sender.get('id',m['chat']['id'])), sender.get('username'));cb(m['chat']['id'],m['message_id'],z['from']['id'],z['id'],z.get('data',''),m['chat'].get('type','private'))
     elif 'message' in u:
      m=u['message'];c=m['chat']['id'];CHAT_TYPES[c]=m.get('chat',{}).get('type','private')
      sender=m.get('from',{}) or {}
      registered(c, sender.get('first_name') or sender.get('last_name') or str(c), sender.get('username'))
      if m.get('web_app_data'):handle_webapp_data(c,m)
      elif m.get('document'):restore_document(c,m)
      elif m.get('text'):process_text(c,m['text'],CHAT_TYPES[c])
    except Exception as er:log('UPDATE '+repr(er))
  except Exception as er:log('POLL '+repr(er));time.sleep(2)
if __name__=='__main__':main()
