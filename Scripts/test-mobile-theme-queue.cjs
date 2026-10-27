const {app,BrowserWindow}=require('electron'),fs=require('node:fs');const wait=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{const w=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}}),js=s=>w.webContents.executeJavaScript(s,true),check=(v,m)=>{if(!v)throw Error(m);};try{
await w.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5197')+'/tests/wall-mobile.html');await wait(700);
for(const style of ['简易','音乐库','音乐墙'])for(const theme of ['浅色模式','深色模式']){
await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(400);await js("document.querySelector('.mv-drawer [aria-label=设置]').click()");await wait(400);
await js(`Array.from(document.querySelectorAll('.mv-style-picker button')).find(b=>b.textContent==='${style}').click()`);await wait(150);
await js(`Array.from(document.querySelectorAll('.mv-mobile-settings .mv-option')).find(b=>b.textContent.startsWith('${theme}')).click()`);await wait(150);
const expected=theme==='浅色模式'?'light':'dark';check(await js(`document.querySelector('main').dataset.theme==='${expected}'&&Array.from(document.querySelectorAll('.mv-mobile-settings .mv-option')).find(b=>b.textContent.startsWith('${theme}')).getAttribute('aria-pressed')==='true'`),'Theme response lost '+style+theme);
await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(300);await js("document.querySelector('.mv-dock [aria-label=播放队列]').click()");await wait(350);
const actual=await js("(()=>{const m=document.querySelector('.mv-modal'),r=m.querySelector('.mv-song'),s=getComputedStyle(r);return {bg:getComputedStyle(m).backgroundColor,row:s.backgroundColor,filter:s.backdropFilter,gap:s.gap,icon:m.querySelector('svg').getAttribute('viewBox')}})()");check(actual.bg===(expected==='light'?'rgb(234, 240, 238)':'rgb(24, 39, 32)')&&actual.filter==='none'&&actual.gap==='10px'&&actual.icon==='0 0 24 24','Queue material drift '+JSON.stringify(actual));console.log('PASS',style,theme,actual);if(style==='音乐墙')fs.writeFileSync('.build/Shared/Core/theme-queue-'+expected+'.png',(await w.webContents.capturePage()).toPNG());
await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(300);
}
await w.reload();await wait(800);check(await js("document.querySelector('main').dataset.theme==='dark'"),'Theme did not persist');console.log('PASS theme survives reload');w.destroy();app.exit(0);
}catch(e){console.error(e);w.destroy();app.exit(1);}});
