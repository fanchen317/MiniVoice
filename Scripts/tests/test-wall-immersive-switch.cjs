require('node:fs').mkdirSync(require('node:path').resolve(__dirname,'../../.build/reports/ui'),{recursive:true});
const {app,BrowserWindow,protocol}=require('electron');
const fs=require('node:fs'),path=require('node:path');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const check=(ok,message)=>{if(!ok)throw Error(message);};
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5190',output=path.resolve(__dirname,'../../.build/reports/ui');
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
let win;const errors=[];const timeout=setTimeout(()=>{console.error('Wall version test timed out');app.exit(1);},120000);
async function js(source){return win.webContents.executeJavaScript(source,true);}
async function click(selector){check(await js(`(()=>{const node=document.querySelector(${JSON.stringify(selector)});if(!node)return false;node.click();return true})()`),`Missing ${selector}`);await wait(120);}
async function shot(name){fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,name+'.png'),(await win.webContents.capturePage()).toPNG());}
async function waitFor(source,message){for(let i=0;i<50;i++){if(await js(source))return;await wait(100);}throw Error(message);}
async function phoneScale(value){
 await js(`(()=>{const slider=document.querySelector('.wp-settings [role=slider]');slider.focus();slider.dispatchEvent(new KeyboardEvent('keydown',{key:'Home',bubbles:true}));slider.dispatchEvent(new KeyboardEvent('keyup',{key:'Home',bubbles:true}));})()`);
 for(let i=60;i<value;i++)await js(`(()=>{const slider=document.querySelector('.wp-settings [role=slider]');slider.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true}));slider.dispatchEvent(new KeyboardEvent('keyup',{key:'ArrowRight',bubbles:true}));})()`);
}
app.whenReady().then(async()=>{try{
 protocol.handle('minivoice-art',request=>{const key=new URL(request.url).pathname,number=Number(key.replace(/\D/g,''))||0;return new Response(`<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><path fill="hsl(${number*43%360},35%,45%)" d="M0 0h512v512H0z"/><circle cx="300" cy="180" r="150" fill="#ffffff30"/><text x="30" y="430" fill="white" font-size="50">MiniVoice ${number}</text></svg>`,{headers:{'Content-Type':'image/svg+xml','Access-Control-Allow-Origin':'*'}});});
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{nodeIntegration:false,contextIsolation:true,backgroundThrottling:false}});win.webContents.on('console-message',(_event,level,message)=>{if(level>=3)errors.push(message);});

 win.setContentSize(1280,800);await win.loadURL(base+'/tests/wall-desktop.html');
 await waitFor("!!document.querySelector('.wall-poster.focused')",'No initial focus');await wait(900);
 await click('.wall-poster.focused [aria-label="展开播放器"]');await wait(850);
 for(const id of ['83','17','62']){
  await js(`window.switchFrames=[];window.switchStart=performance.now();function sampleSwitch(){const n=document.querySelector('.wall-poster.focused'),s=document.querySelector('.wall-surface');if(n&&s){const r=n.getBoundingClientRect(),b=s.getBoundingClientRect();window.switchFrames.push({id:n.dataset.trackId,x:r.x-b.x,y:r.y-b.y,w:r.width/b.width,h:r.height/b.height});}if(performance.now()-window.switchStart<650)requestAnimationFrame(sampleSwitch);}sampleSwitch();window.miniVoice.command('play',{id:'${id}'});`);await wait(750);
  const frames=await js('window.switchFrames');const selected=frames.filter(f=>f.id===id);
  check(selected.length>5&&selected.every(f=>Math.abs(f.x)<2&&Math.abs(f.y)<2&&Math.abs(f.w-1)<.01&&Math.abs(f.h-1)<.01),'Immersive switch moved across wall: '+JSON.stringify(selected.slice(0,5)));
 }
 await shot('mac-immersive-switch-fixed');console.log('PASS immersive distant song switches retain full-screen bounds across intermediate frames');
 clearTimeout(timeout);app.exit(0);
}catch(error){console.error(error);clearTimeout(timeout);app.exit(1);}});
