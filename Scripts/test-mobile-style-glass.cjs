const {app,BrowserWindow}=require('electron'),fs=require('node:fs'),path=require('node:path');
let win;const wait=ms=>new Promise(r=>setTimeout(r,ms)),js=s=>win.webContents.executeJavaScript(s,true),check=(v,m)=>{if(!v)throw Error(m)};
const until=async(s,m)=>{for(let i=0;i<100;i++){if(await js(s))return;await wait(50)}throw Error(m)};
const shot=async n=>fs.writeFileSync(path.resolve(__dirname,'../.build/Shared/Core/'+n+'.png'),(await win.webContents.capturePage()).toPNG());
const click=async s=>{await js(`document.querySelector(${JSON.stringify(s)}).click();true`);await wait(350)};
const timeout=setTimeout(()=>app.exit(1),60000);
app.whenReady().then(async()=>{try{
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5199')+'/tests/wall-mobile.html');await until("!!document.querySelector('.mv-wall-card')",'wall missing');await click('.mv-wall-card[data-wall-id="0"]');
 check(await js("(()=>{const n=document.querySelector('.wp-status'),s=getComputedStyle(n);return n.textContent==='已暂停'&&s.display!=='none'&&parseFloat(s.borderRadius)>=50&&s.borderTopStyle==='solid'&&n.querySelectorAll('i').length===3&&[...n.querySelectorAll('i')].every(n=>n.getAnimations().length===0)})()"),'Paused badge must have a mint pill and static waveform');await shot('mobile-thin-status-paused');
 await click('.wp-controls [data-wall-transport=play]');await wait(500);check(await js("document.querySelector('.wp-status').textContent==='正在播放'&&document.querySelector('.wp-status i').getAnimations().length===1"),'Playing waveform missing');await shot('mobile-thin-status-playing');await click('.wp-controls [data-wall-transport=play]');
 await click('[aria-label=打开侧边栏]');
 for(const theme of ['dark','light']){
  if(theme==='light'){await click('.mv-drawer [aria-label=设置]');await js("Array.from(document.querySelectorAll('.mv-mobile-settings button')).find(n=>n.textContent.startsWith('浅色模式')).click();true");await wait(500);await click('[aria-label=关闭弹窗]');await click('[aria-label=打开侧边栏]');}check(await js(`document.querySelector('main').dataset.theme===${JSON.stringify(theme)}`),'Theme must be persisted through page actions');
  check(await js("(()=>{const a=getComputedStyle(document.querySelector('.mv-drawer')),b=getComputedStyle(document.querySelector('[data-wall-control=settings]'));return a.backgroundColor===b.backgroundColor&&a.backdropFilter===b.backdropFilter&&a.backdropFilter.includes('10px')&&parseFloat(a.backgroundColor.split(',').at(-1))<.3})()"),'Wall drawer and buttons must share thin glass');await shot('mobile-thin-drawer-'+theme);
 }
 await js('window.captureStyleFixture=async()=>window.styleFixtureSnapshot;true');await js('window.styleFixtureSnapshot='+JSON.stringify((await win.webContents.capturePage()).toDataURL()));
 await js("window.rasterDraws=0;window.originalDraw=CanvasRenderingContext2D.prototype.drawImage;CanvasRenderingContext2D.prototype.drawImage=function(...args){window.rasterDraws++;return window.originalDraw.apply(this,args)};document.querySelector('.mv-brand-logo').click();true");
 await until("!!document.querySelector('.mv-style-fragment-sweep canvas')",'Fragment tiles missing');
 const prepared=await js('window.rasterDraws');await wait(100);check(await js("document.querySelector('.mv-style-fragment-sweep').dataset.renderer==='compositor'&&[...document.querySelectorAll('.mv-style-fragment-sweep canvas')].every(n=>n.getAnimations().length===1)"),'Fragments must use compositor animations');await shot('mobile-thin-fragments');await wait(100);check(prepared===await js('window.rasterDraws'),'Animation still repaints canvas every frame');
 await until("document.querySelector('main').dataset.styleBusy==='false'",'Transition not cleaned');
 // Rapid reentry must commit the latest requested style and remove all tiles.
 await js("document.querySelector('.mv-brand-logo').click();document.querySelector('.mv-brand-logo').click();true");await until("document.querySelector('main').dataset.styleBusy==='false'",'Rapid switches stuck');check(await js("document.querySelector('main').dataset.style==='wall'&&!document.querySelector('.mv-style-fragment-sweep')"),'Latest style intent or cleanup lost');
 console.log('PASS paused/playing badge, matching thin glass in light/dark, one-time raster draws='+prepared+', compositor-only frames, rapid style intent and cleanup');win.destroy();clearTimeout(timeout);app.exit(0);
 }catch(e){console.error(e.stack);if(win)await shot('mobile-thin-failure');win?.destroy();clearTimeout(timeout);app.exit(1)}});
