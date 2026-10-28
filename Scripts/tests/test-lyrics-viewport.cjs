require('node:fs').mkdirSync(require('node:path').resolve(__dirname,'../../.build/reports/ui'),{recursive:true});
const {app,BrowserWindow}=require('electron'),fs=require('node:fs'),path=require('node:path');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{const win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}}),js=async s=>{const result=await win.webContents.executeJavaScript('(()=>{try{return '+s+'}catch(e){return {failure:e.message}}})()',true);if(result?.failure)throw Error(result.failure);return result;};try{
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5197';
for(const device of ['phone','mac']){
if(device==='mac')win.setContentSize(972,1310);
await win.loadURL(base+'/tests/wall-'+(device==='phone'?'mobile':'desktop')+'.html');await wait(800);
if(device==='phone'){await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(400);await js("document.querySelector('.mv-brand-logo').click()");await wait(650);await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(400);}else{await js("document.querySelector('.brand-logo').click()");await wait(1100);}
const selector=device==='phone'?'.mv-lyric-lines':'.simple-lyrics .lyrics-scroll',line=device==='phone'?'button[data-active]':'.lyric-line';
const result=await js(`(()=>{const v=document.querySelector('${selector}'),rows=[...v.querySelectorAll('${line}')],style=getComputedStyle(v);if(v.getBoundingClientRect().bottom>v.closest('.mv-lyrics,.simple-lyrics').getBoundingClientRect().bottom+1)throw Error('Lyric viewport escapes card');if(style.maskImage==='none')throw Error('Missing fades');if(${device==='mac'}){const h=document.querySelector('.simple-lyrics>header');if(getComputedStyle(h).position!=='absolute')throw Error('Header reserves blank row');}for(const i of [0,14,29]){const r=rows[i];v.scrollTop+=r.getBoundingClientRect().top-v.getBoundingClientRect().top+r.clientHeight/2-v.clientHeight/2;const delta=Math.abs(r.getBoundingClientRect().top+r.clientHeight/2-v.getBoundingClientRect().top-v.clientHeight/2);if(delta>2)throw Error('Line '+i+' cannot center: '+delta);}return {height:v.clientHeight,fade:style.maskImage,padding:getComputedStyle(${device==='phone'?'v':"v.querySelector('.lyrics-lines')"}).paddingBottom}})()`);
await js(`(()=>{const v=document.querySelector('${selector}'),r=v.querySelector('[data-active=true],.current');if(r)v.scrollTop+=r.getBoundingClientRect().top-v.getBoundingClientRect().top+r.clientHeight/2-v.clientHeight/2;return true})()`);
console.log('PASS',device,'first/middle/last center, viewport fade and header overlay',result);
fs.writeFileSync(path.resolve('.build/reports/ui/lyrics-viewport-'+device+'.png'),(await win.webContents.capturePage()).toPNG());
}
win.destroy();app.exit(0);
}catch(e){console.error(e);win.destroy();app.exit(1);}});
