const {app,BrowserWindow}=require('electron'),fs=require('node:fs'),path=require('node:path');
const output=path.resolve(__dirname,'../../.build/reports/ui');fs.mkdirSync(output,{recursive:true});
let win;const wait=ms=>new Promise(r=>setTimeout(r,ms)),check=(v,m)=>{if(!v)throw Error(m)},js=s=>win.webContents.executeJavaScript(s,true);
const click=async s=>{await js(`document.querySelector(${JSON.stringify(s)}).click();true`);await wait(350)};
const shot=async n=>fs.writeFileSync(path.join(output,n+'.png'),(await win.webContents.capturePage()).toPNG());
const timeout=setTimeout(()=>app.exit(1),120000);
app.whenReady().then(async()=>{try{
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});
 await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5210')+'/tests/wall-mobile.html');await wait(900);
 for(const style of ['wall','simple','library']){
  check(await js(`document.querySelector('main').dataset.style===${JSON.stringify(style)}`),'Wrong fixture style');
  for(const theme of ['light','dark']){
   await click('[aria-label=打开侧边栏]');await click('.mv-drawer [aria-label=设置]');
   await js(`Array.from(document.querySelectorAll('.mv-mobile-settings button')).find(n=>n.textContent.startsWith(${JSON.stringify(theme==='light'?'浅色模式':'深色模式')})).click();true`);await wait(400);
   const sheet=await js("(()=>{const n=document.querySelector('.mv-modal'),s=getComputedStyle(n);return {text:s.color,sample:s.backdropFilter,tint:s.backgroundColor,close:n.querySelector('header>button').getBoundingClientRect().width}})()");
   check(sheet.text===(theme==='light'?'rgb(34, 40, 48)':'rgb(240, 243, 248)')&&sheet.sample.includes('0.72')&&sheet.close>=44,'Neutral sheet palette/sample/close target: '+JSON.stringify(sheet));
   await shot('neutral-'+style+'-settings-'+theme);await click('[aria-label=关闭弹窗]');
   await click('[aria-label=打开侧边栏]');
   check(await js("(()=>{const n=document.querySelector('.mv-drawer'),s=getComputedStyle(n.querySelector('nav'));return s.backgroundColor==='rgba(0, 0, 0, 0)'&&s.backgroundImage==='none'&&s.boxShadow==='none'})()"),'Drawer has a second tinted nav slab');
   check(await js("getComputedStyle(document.querySelector('.mv-drawer-shade'),'::before').clipPath==='none'"),'Scrim contaminates the glass sample');
   await shot('neutral-'+style+'-drawer-'+theme);await click('[aria-label=关闭侧边栏]');
   if(style==='wall'){
    await click('[aria-label=音乐墙设置]');
    const rail=await js("(()=>{const n=document.querySelector('.wp-scale-controls .mv-slider'),dot=getComputedStyle(n.querySelector('.mv-slider-mark>i'));return {h:n.getBoundingClientRect().height,marks:n.querySelectorAll('.mv-slider-mark').length,halo:dot.boxShadow,knob:getComputedStyle(n.querySelector('.mv-slider-knob')).width,track:getComputedStyle(n.querySelector('.mv-slider-track')).height}})()");
    check(rail.h>=44&&rail.marks===7&&rail.halo==='none'&&rail.knob==='18px'&&rail.track==='4px','Scale rail clarity/hit target: '+JSON.stringify(rail));
    await js("document.querySelector('.wp-scale-controls .mv-slider').focus();true");
    for(const key of ['HOME','ARROWRIGHT','ARROWRIGHT']){const k=key==='HOME'?'Home':'ArrowRight';await js(`(()=>{const n=document.querySelector('.wp-scale-controls .mv-slider');n.dispatchEvent(new KeyboardEvent('keydown',{key:'${k}',bubbles:true}));n.dispatchEvent(new KeyboardEvent('keyup',{key:'${k}',bubbles:true}));})()`);}
    await wait(350);check(await js("document.querySelector('.wp-scale-controls .mv-slider').getAttribute('aria-valuenow')==='62'"),'Continuous 62 percent zoom lost');
    await shot('neutral-wall-scale-'+theme);await click('[aria-label=关闭弹窗]');
   }
  }
  if(style!=='library'){await click('[aria-label=打开侧边栏]');await click('.mv-brand-logo');await wait(850);await click('[aria-label=关闭侧边栏]');}
 }
 console.log('PASS three mobile styles x light/dark: neutral sampled panels, no stacked nav slab, 44px close/slider targets, crisp marks and 62% keyboard zoom');
 win.destroy();clearTimeout(timeout);app.exit(0);
}catch(error){console.error(error.stack);if(win)await shot('neutral-surface-failure');win?.destroy();clearTimeout(timeout);app.exit(1)}});
