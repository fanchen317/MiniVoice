// Run with Electron. Exercises the actual desktop wall, including an original
// cover decoding while the poster's 600ms expansion FLIP is in progress.
const {app,BrowserWindow,protocol}=require('electron');
const {spawn}=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const repo=path.resolve(__dirname,'../../..'),output=path.join(repo,'.build/reports/ui/wall-artwork-lifecycle');
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5197';
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const assert=(condition,message)=>{if(!condition)throw Error(message);};
let server,win,releaseOriginal;
const detailGate=new Promise(resolve=>{releaseOriginal=resolve;});
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
const timeout=setTimeout(()=>{console.error('Artwork lifecycle test timed out');server?.kill();app.exit(1);},45000);
const js=source=>win.webContents.executeJavaScript(source,true);
async function until(source,message){for(let i=0;i<100;i++){if(await js(source))return;await wait(60);}throw Error(message);}
app.whenReady().then(async()=>{try{
 if(!process.env.MINIVOICE_WALL_TEST_URL){server=spawn(process.execPath,[path.join(repo,'Shared/UI/node_modules/vite/bin/vite.js'),'--config',path.join(repo,'Shared/UI/vite.wall-test.config.mjs'),'--host','127.0.0.1','--port','5197','--strictPort'],{cwd:repo,env:{...process.env,ELECTRON_RUN_AS_NODE:'1'},stdio:'ignore'});let ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/tests/wall-desktop.html')).ok){ready=true;break;}}catch{}await wait(60);}assert(ready,'Vite fixture server failed to start');}
 protocol.handle('minivoice-art',async request=>{const original=new URL(request.url).hostname==='detail';if(original)await detailGate;return new Response(`<svg xmlns="http://www.w3.org/2000/svg" width="${original?1200:512}" height="${original?800:512}"><rect width="100%" height="100%" fill="#305353"/><rect x="120" y="100" width="180" height="360" fill="#e8b483"/><text x="600" y="650" fill="white" font-size="70">composition fixture</text></svg>`,{headers:{'Content-Type':'image/svg+xml','Access-Control-Allow-Origin':'*'}});});
 win=new BrowserWindow({show:false,width:1200,height:800,webPreferences:{contextIsolation:true,nodeIntegration:false,backgroundThrottling:false}});
 await win.loadURL(base+'/tests/wall-desktop.html?unfocused=1');await until("document.querySelector('.wall-poster[data-track-id=\"0\"] img.cover')?.naturalWidth===512",'Initial preview did not load');await js("window.miniVoice.command('play',{id:'0'})");await until("document.querySelector('.wall-poster.focused [aria-label=展开播放器]')",'Playback focus did not settle');
 await wait(650);await js("window.retainedPoster=document.querySelector('.wall-poster.focused');document.querySelector('.wall-poster.focused [aria-label=展开播放器]').click()");
 assert(await js("window.retainedPoster===document.querySelector('.wall-poster.focused')"),'Expansion remounted the poster and lost its animation state');
 // Current host prepares the original before starting expansion.
 await wait(160);releaseOriginal();
 await until("document.querySelector('.wall-poster.focused').getAnimations().some(animation=>animation.playState==='running')",'Expansion did not animate');
 await js(`window.deformSamples=[];window.deformStart=performance.now();function sampleDeform(){const image=document.querySelector('.wall-poster.focused img.cover');if(image?.naturalWidth){const r=image.getBoundingClientRect();if(r.width>1&&r.height>1)window.deformSamples.push(r.width/r.height/(image.naturalWidth/image.naturalHeight));}if(performance.now()-window.deformStart<800)requestAnimationFrame(sampleDeform);}sampleDeform();`);
 await wait(160);releaseOriginal();
 await until("document.querySelector('.wall-poster.focused img.cover')?.naturalWidth===1200",'Deferred original never replaced the preview');
 await wait(750);
 const samples=await js('window.deformSamples');assert(samples.length>5&&samples.every(ratio=>Math.abs(ratio-1)<.015),'Image stretched during expansion: '+JSON.stringify(samples));
 const first=await js(`(()=>{const surface=document.querySelector('.wall-surface'),card=document.querySelector('.wall-poster.focused'),image=card.querySelector('img.cover'),blur=card.querySelector('.mv-artwork-blur'),matrix=new DOMMatrix(getComputedStyle(image).transform),cover={width:parseFloat(image.style.width)*matrix.a,height:parseFloat(image.style.height)*matrix.d},frame=card.getBoundingClientRect(),wall=surface.getBoundingClientRect(),request=window.desktopWallFixture.calls.find(item=>item.name==='artworkSubjects');return {cover,frame:{width:frame.width,height:frame.height},wall:{width:wall.width,height:wall.height},imageRatio:image.naturalWidth/image.naturalHeight,blurRatio:blur.naturalWidth/blur.naturalHeight,sharpTransform:image.style.transform,blurTransform:blur.style.transform,request:request?.payload};})()`);
 assert(Math.abs(first.cover.width/first.cover.height-first.imageRatio)<.001,'Original retained the preview aspect after decoding during expansion');
 assert(first.cover.width>=first.frame.width-2&&first.cover.height>=first.frame.height-2,'Artwork no longer covers the expanded clip');
 assert(Math.abs(first.frame.width-first.wall.width)<1&&Math.abs(first.frame.height-first.wall.height)<1,'Expanded frame does not match the actual wall viewport');
 assert(first.imageRatio===first.blurRatio&&first.sharpTransform===first.blurTransform,'Sharp and blurred layers use different source geometry');
 assert(first.request?.viewport?.width>0&&first.request?.viewport?.height>0,'Detection did not receive the measured display target');
 assert(first.request.viewport.width===first.wall.width&&first.request.viewport.height===first.wall.height,'Detection planned against a tile or physical screen instead of the wall viewport');
 win.setContentSize(1600,600);await wait(350);
 const resized=await js(`(()=>{const surface=document.querySelector('.wall-surface').getBoundingClientRect(),card=document.querySelector('.wall-poster.focused').getBoundingClientRect(),image=document.querySelector('.wall-poster.focused img.cover'),matrix=new DOMMatrix(getComputedStyle(image).transform);return {width:surface.width,height:surface.height,cardWidth:card.width,cardHeight:card.height,ratio:parseFloat(image.style.width)*matrix.a/(parseFloat(image.style.height)*matrix.d)};})()`);
 assert(Math.abs(resized.cardWidth-resized.width)<1&&Math.abs(resized.cardHeight-resized.height)<1,'Resize left an expanded target from the previous viewport');assert(Math.abs(resized.ratio-1.5)<.001,'Resize distorted the original cover');
 fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'geometry.json'),JSON.stringify({first,resized},null,2));fs.writeFileSync(path.join(output,'expanded-ultrawide.png'),(await win.webContents.capturePage()).toPNG());
 console.log('PASS deferred original decode, full-surface target context, resize, sharp/blur alignment');
 clearTimeout(timeout);win.destroy();server?.kill();app.exit(0);
 }catch(error){console.error(error);clearTimeout(timeout);win?.destroy();server?.kill();app.exit(1);}});
