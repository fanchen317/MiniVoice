// Pending artwork must never expose pure-black posters. Loaded pixels keep the
// existing shade and caption; this does not measure device compositor FPS.
const {app,BrowserWindow,protocol}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
app.setPath('userData',fs.mkdtempSync(path.join(os.tmpdir(),'minivoice-wall-pending-')));
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let win,release=[];const timer=setTimeout(()=>{console.error('Pending artwork test timed out');app.exit(1);},30000);
app.whenReady().then(async()=>{try{
 protocol.handle('minivoice-art',()=>new Promise(resolve=>release.push(()=>resolve(new Response('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><path fill="white" d="M0 0h512v512H0z"/></svg>',{headers:{'Content-Type':'image/svg+xml'}})))));
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});
 const js=source=>win.webContents.executeJavaScript(source,true).catch(error=>{throw Error('Renderer failed: '+source,{cause:error});});
 await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5193')+'/tests/wall-mobile.html');await wait(700);
 await js("window.originalWallNodes=new Set(document.querySelectorAll('.mv-wall-card'));wallFixture.state.songs=wallFixture.state.songs.map(song=>({...song,artwork:'minivoice-art://cover/'+song.id}));true");
 for(let i=0;i<40&&!release.length;i++)await wait(50);
 assert.ok(release.length,'No pending cover requests');
 await js("document.querySelector('.mv-cover-wall').dispatchEvent(new WheelEvent('wheel',{deltaX:2400,deltaY:1400,bubbles:true,cancelable:true}));true");await wait(120);
 const point=await js(`(()=>{for(const tile of document.querySelectorAll('.mv-wall-card')){const r=tile.getBoundingClientRect(),img=tile.querySelector('img'),left=Math.max(r.left+12,20),right=Math.min(r.right-12,innerWidth-20),top=Math.max(r.top+12,130),bottom=Math.min(r.bottom-75,innerHeight-180);if(!originalWallNodes.has(tile)&&img?.getAttribute('src').startsWith('minivoice-art:')&&right-left>24&&bottom-top>24){window.pendingTile=tile;return {x:(left+right)/2,y:(top+bottom)/2};}}throw Error('No unobscured fresh tile');})()`);
 const pixel=async()=>{const picture=await win.webContents.capturePage(),size=picture.getSize(),data=picture.toBitmap(),scale=size.width/390,x=Math.floor(point.x*scale),y=Math.floor(point.y*scale),offset=(y*size.width+x)*4;return {rgb:[data[offset+2],data[offset+1],data[offset]],picture};};
 const pending=await pixel();
 fs.mkdirSync('.build/reports/ui/wall-pending-artwork',{recursive:true});fs.writeFileSync('.build/reports/ui/wall-pending-artwork/pending.png',pending.picture.toPNG());
 assert.ok(Math.max(...pending.rgb)>25,'Pending cover exposed black floor: '+pending.rgb);
 const flush=()=>release.splice(0).forEach(resolve=>resolve());flush();
 for(let i=0;i<80;i++){flush();if(await js("pendingTile.querySelector('img')?.naturalWidth>0"))break;await wait(50);}
 assert.ok(await js("pendingTile.querySelector('img')?.naturalWidth>0"),'Loaded poster did not recover');await wait(100);
 const loaded=await pixel();fs.writeFileSync('.build/reports/ui/wall-pending-artwork/loaded.png',loaded.picture.toPNG());
 assert.ok(loaded.rgb.every(value=>value>=150&&value<=185),'Loaded poster shade changed: '+loaded.rgb);
 fs.writeFileSync('.build/reports/ui/wall-pending-artwork/pixels.json',JSON.stringify({pending:pending.rgb,loaded:loaded.rgb},null,2));
 console.log('PASS Android pending covers retain nonblack app placeholder and loaded white artwork retains the original shade '+JSON.stringify({pending:pending.rgb,loaded:loaded.rgb}));clearTimeout(timer);win.destroy();app.exit(0);
}catch(error){console.error(error);clearTimeout(timer);win?.destroy();app.exit(1);}});
