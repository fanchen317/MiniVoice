const {app,BrowserWindow,ipcMain,protocol,nativeImage}=require('electron'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
app.on('window-all-closed',()=>{});
app.setPath('userData',fs.mkdtempSync(path.join(os.tmpdir(),'minivoice-platform-parity-')));
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const out=path.resolve('.build/reports/build/desktop-platform-parity');fs.mkdirSync(out,{recursive:true});
const covers=new Map();let win,state,platform,settings=0;const results=[];
const timeout=setTimeout(()=>app.exit(1),90000);
ipcMain.handle('parity:command',(_,command)=>{if(command.action==='openSettings')settings++;if(command.action==='orderedTracks')return (state?.tracks||[]).map(t=>t.id);if(command.action==='getSettings')return {folders:[],shortcuts:[],statusIconStyle:'colored'};return {};});
app.whenReady().then(async()=>{try{
 const presentation=require('../../Windows/electron/artwork-presentation.cjs').artworkPresentation({directory:'/synthetic',nativeImage,readFile:async file=>covers.get(path.basename(file))});
 const titles=['画心','坏女孩','幻听','幻听（Live）','黄昏'];const tracks=[];
 for(let index=0;index<40;index++){
  const key=index.toString(16).padStart(64,'0'),pixels=Buffer.alloc(128*128*4),base=index===2?[125,45,54]:[45+(index*37)%140,35+(index*53)%130,40+(index*29)%120];
  for(let y=0;y<128;y++)for(let x=0;x<128;x++){const at=(y*128+x)*4;pixels[at]=Math.min(255,base[2]+Math.round(y/9));pixels[at+1]=Math.min(255,base[1]+Math.round(x/10));pixels[at+2]=Math.min(255,base[0]+Math.round(y/7));pixels[at+3]=255;}
  covers.set(key,nativeImage.createFromBitmap(pixels,{width:128,height:128}).toPNG());
  tracks.push({id:'synthetic-'+index,path:'/synthetic/'+index+'.mp3',title:titles[index]||'参考歌曲 '+index,artist:index===2?'许嵩':'测试歌手 '+index,album:'测试专辑',duration:273,artworkKey:key});
 }
 protocol.handle('minivoice-art',request=>{const data=covers.get(new URL(request.url).pathname.slice(1));return data?new Response(data,{headers:{'Content-Type':'image/png'}}):new Response('',{status:404});});
 const current={...tracks[2],lyrics:'[00:32.00]在远方的时候\n[00:40.00]又想你到泪流',lines:[{time:32,text:'在远方的时候',translation:'',words:[]},{time:40,text:'又想你到泪流',translation:'',words:[]}],backdropColors:await presentation.colors(tracks[2].artworkKey)};
 if(!current.backdropColors||current.backdropColors[0][0]<=current.backdropColors[0][1])throw Error('Real cover palette missing/wrong channel order');
 for(platform of ['macos','windows']){
  win=new BrowserWindow({width:759,height:603,frame:false,show:false,webPreferences:{preload:path.resolve('Scripts/tests/fixtures/desktop-parity-preload.cjs'),additionalArguments:['--parity-platform='+platform],contextIsolation:true,sandbox:false}});
  await win.loadFile(path.resolve('Windows/ui/index.html'));await wait(150);win.webContents.send('parity:catalog',tracks);
  for(const style of ['library','wall','simple']){
   state={tracks,interfaceStyle:style,appearance:'light',folders:['/synthetic'],favorites:[],recent:[],jobs:[{id:'synthetic-completed',title:'参考后台任务',detail:'已完成',finished:true,failed:false}],tasks:{hasUnread:true},playlists:[{id:'test',name:'测试',paths:tracks.slice(0,2).map(t=>t.path)}],volume:1,mode:'shuffle',playing:current,selected:current,isPlaying:false,outputDevices:[{id:'reference',name:'参考蓝牙音频输出'}],outputDevice:'reference'};
   win.webContents.send('parity:state',state);win.webContents.send('parity:clock',{time:32,duration:273,playing:false});await wait(900);
   if(style==='wall'){
    await win.webContents.executeJavaScript(`(()=>{const card=[...document.querySelectorAll('.wall-poster')].find(node=>node.textContent.includes('幻听'));card?.click()})()`);await wait(800);
   }
   const metrics=await win.webContents.executeJavaScript(`(()=>{const box=selector=>{const r=document.querySelector(selector)?.getBoundingClientRect();return r?{x:r.x,y:r.y,width:r.width,height:r.height}:null};return {main:box('.app'),sidebar:box('.sidebar'),workspace:box('.workspace'),player:box('.player'),simpleHero:box('.simple-hero'),songPanel:box('.songs-panel'),palette:document.querySelector('.cover-palette')?.style.background,images:[...document.querySelectorAll('img')].filter(image=>image.complete&&image.naturalWidth>0).length}})()`);
   if(metrics.main.width!==759||metrics.main.height!==603||metrics.images<2)throw Error('Missing complete reference state: '+JSON.stringify(metrics));
   fs.writeFileSync(path.join(out,platform+'-'+style+'.png'),(await win.webContents.capturePage()).toPNG());results.push({platform,style,...metrics});
  }
  win.destroy();
 }
 for(const style of ['library','wall','simple']){
  const mac=results.find(r=>r.platform==='macos'&&r.style===style),windows=results.find(r=>r.platform==='windows'&&r.style===style);
  for(const key of ['main','sidebar','workspace','player','simpleHero','songPanel']){
   if(!mac[key]&&!windows[key])continue;
   if(!mac[key]||!windows[key])throw Error('Platform layout mismatch '+style+' '+key);
   for(const dimension of ['x','y','width','height'])if(Math.abs(mac[key][dimension]-windows[key][dimension])>.6)throw Error('Geometry drift '+style+' '+key+' '+dimension);
  }
  if(mac.palette!==windows.palette)throw Error('Palette drift '+style);
 }
 fs.writeFileSync(path.join(out,'comparison.json'),JSON.stringify({referenceLogicalSize:[759,603],syntheticTracks:40,nativeWindowsExecution:false,geometryTolerance:.6,results},null,2));
 console.log('DESKTOP_PLATFORM_PARITY_PASS same logical viewport, covers, lyrics, palette and container geometry across 3 styles');clearTimeout(timeout);app.exit(0);
 }catch(error){console.error(error);app.exit(1);}});
