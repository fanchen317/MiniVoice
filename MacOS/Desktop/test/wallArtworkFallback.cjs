// Actual wall regression: a missing original uses a trimmed preview, then the
// same artwork identity is repaired and can upgrade to original coordinates.
const {app,BrowserWindow,protocol}=require('electron');
const {spawn}=require('node:child_process'),path=require('node:path');
const repo=path.resolve(__dirname,'../../..'),base='http://127.0.0.1:5198';
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const assert=(condition,message)=>{if(!condition)throw Error(message);};
let server,win,originalAvailable=false;
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
const timeout=setTimeout(()=>{console.error('Wall artwork fallback test timed out');server?.kill();app.exit(1);},50000);
const js=source=>win.webContents.executeJavaScript(source,true);
async function until(source,message){for(let i=0;i<150;i++){if(await js(source))return;await wait(60);}throw Error(message);}
app.whenReady().then(async()=>{try{
 server=spawn(process.execPath,[path.join(repo,'Shared/UI/node_modules/vite/bin/vite.js'),'--config',path.join(repo,'Shared/UI/vite.wall-test.config.mjs'),'--host','127.0.0.1','--port','5198','--strictPort'],{cwd:repo,env:{...process.env,ELECTRON_RUN_AS_NODE:'1'},stdio:'ignore'});
 let ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/tests/wall-desktop.html')).ok){ready=true;break;}}catch{}await wait(60);}assert(ready,'Vite fixture server failed to start');
 protocol.handle('minivoice-art',request=>{
  const url=new URL(request.url),strict=url.searchParams.get('analysis')==='1';if(strict&&!originalAvailable)return new Response('',{status:404});
  const original=strict&&originalAvailable,width=original?1200:512,height=original?800:512;
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><rect width="100%" height="100%" fill="#607080"/></svg>`;
  return new Response(svg,{headers:{'Content-Type':'image/svg+xml','Access-Control-Allow-Origin':'*','Cache-Control':'no-store'}});
 });
 win=new BrowserWindow({show:false,width:500,height:800,webPreferences:{contextIsolation:true,nodeIntegration:false,backgroundThrottling:false}});
 await win.loadURL(base+'/tests/wall-desktop.html?unfocused=1');
 await until("document.querySelector('.wall-poster[data-track-id=\"0\"] img.cover')?.naturalWidth===512",'Initial preview did not load');
 await js(`(async()=>{const {warmArtworkSubjects}=await import('/src/components/artworkFocus.js');await warmArtworkSubjects('minivoice-art://cover/cover-0?v=1',async()=>[{x:.80,y:.2,width:.1,height:.2,face:1,confidence:1}],{width:500,height:800},{fixedQuality:true});})()`);
 await js("window.miniVoice.command('play',{id:'0'})");
 await until("document.querySelector('.wall-poster.focused [aria-label=展开播放器]')",'Focus did not settle');await wait(300);
 await js("document.querySelector('.wall-poster.focused [aria-label=展开播放器]').click()");
 await until("document.querySelector('.wall-poster.focused [aria-label=收起播放器]')",'Expansion failed when strict original was missing');
 await wait(700);
 const fallback=await js(`(()=>{const card=document.querySelector('.wall-poster.focused'),image=card.querySelector('img.cover'),blur=card.querySelector('.mv-artwork-blur');return {src:image?.currentSrc,width:image?.naturalWidth,focal:Number(image?.dataset.focalX),blur:blur?.currentSrc};})()`);
 assert(fallback.width===512&&fallback.src.includes('://cover/'),'missing original did not retain preview: '+JSON.stringify(fallback));
 assert(Math.abs(fallback.focal-.5)<.03,'cached original-space face affected fallback preview: '+JSON.stringify(fallback));
 assert(fallback.blur===fallback.src,'fallback blur used a different image: '+JSON.stringify(fallback));
 await until("document.querySelector('.wall-poster.focused [aria-label=收起播放器]')",'Collapse control missing');
 await js("document.querySelector('.wall-poster.focused [aria-label=收起播放器]').click()");await wait(750);originalAvailable=true;
 await until("document.querySelector('.wall-poster.focused [aria-label=展开播放器]')",'Expand control missing after collapse');
 await js("document.querySelector('.wall-poster.focused [aria-label=展开播放器]').click()");
 await until("document.querySelector('.wall-poster.focused img.cover')?.naturalWidth===1200",'Repaired original did not load');await wait(800);
 const repaired=await js(`(()=>{const card=document.querySelector('.wall-poster.focused'),image=card.querySelector('img.cover'),blur=card.querySelector('.mv-artwork-blur');return {src:image?.currentSrc,width:image?.naturalWidth,focal:Number(image?.dataset.focalX),blur:blur?.currentSrc};})()`);
 assert(repaired.src.includes('analysis=1'),'repaired wall did not use strict original');assert(repaired.focal>.7,'original-space face was not restored after repair: '+JSON.stringify(repaired));assert(repaired.blur===repaired.src,'repaired original blur did not match sharp image');
 console.log('PASS missing original keeps preview isolated; restored original resumes semantic crop');clearTimeout(timeout);win.destroy();server.kill();app.exit(0);
}catch(error){console.error(error);clearTimeout(timeout);win?.destroy();server?.kill();app.exit(1);}});
