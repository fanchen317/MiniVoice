const {app,BrowserWindow,ipcMain}=require('electron'),fs=require('node:fs'),path=require('node:path');
const wait=ms=>new Promise(r=>setTimeout(r,ms)),out=path.resolve('.build/reports/build/windows-layout');fs.mkdirSync(out,{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.join(require('node:os').tmpdir(),'minivoice-layout-')));
let win,settings=0;ipcMain.handle('fixture:command',(_,r)=>{if(r.action==='openSettings')settings++;if(r.action==='getSettings')return {folders:[],shortcuts:[],statusIconStyle:'colored'};return {};});
const timer=setTimeout(()=>app.exit(1),60000);
app.whenReady().then(async()=>{try{
 win=new BrowserWindow({width:1200,height:820,show:false,frame:false,webPreferences:{preload:path.resolve('Scripts/tests/fixtures/windows-layout-preload.cjs'),contextIsolation:true,sandbox:false}});
 require('../../Windows/electron/windows-shell.cjs').removeMenu(win,()=>settings++);
 await win.loadFile(path.resolve('Windows/ui/index.html'));await wait(300);
 const cases=[];
 for(const style of ['simple','library','wall'])for(const appearance of ['light','dark']){
  win.webContents.send('fixture:state',{interfaceStyle:style,appearance,folders:[],favorites:[],recent:[],playlists:[],jobs:[],outputDevices:[{id:'default',name:'系统默认输出'}],volume:1,mode:'list'});await wait(650);
  const metrics=await win.webContents.executeJavaScript(`(()=>{const box=s=>{const r=document.querySelector(s)?.getBoundingClientRect();return r?{x:r.x,y:r.y,width:r.width,height:r.height}:null};return {platform:document.documentElement.dataset.platform,main:box('.app'),title:box('.titlebar'),settings:box('.windows-title-actions button'),sidebar:box('.sidebar'),workspace:box('.workspace'),tools:box('.window-tools')}})()`);
  if(metrics.platform!=='windows'||metrics.title.height!==32||metrics.settings!==null||metrics.main.width!==1200)throw Error('Invalid layout '+JSON.stringify(metrics));
  fs.writeFileSync(path.join(out,`${style}-${appearance}.png`),(await win.webContents.capturePage()).toPNG());cases.push({style,appearance,...metrics});
 }
 const song={id:'synthetic-song',path:'/synthetic/song.mp3',title:'测试歌曲 · 长标题对齐检查',artist:'测试歌手',album:'测试专辑',duration:180,artworkKey:'',lyrics:'',lines:[]};
 win.webContents.send('fixture:catalog',[song]);
 for(const [style,appearance,width] of [['library','light',1200],['library','dark',1200],['simple','light',560],['wall','dark',560]]){
  win.setSize(width,820);win.webContents.send('fixture:state',{interfaceStyle:style,appearance,folders:['/synthetic'],favorites:[],recent:[],playlists:[],jobs:[],outputDevices:[],volume:1,mode:'list',playing:song,selected:song,isPlaying:false});await wait(750);
  const metrics=await win.webContents.executeJavaScript(`(()=>{const main=document.querySelector('.app').getBoundingClientRect();return {mainWidth:main.width,menuText:document.querySelector('.titlebar').textContent,text:document.body.textContent.includes('测试歌曲')}})()`);
  if(metrics.mainWidth!==width||metrics.menuText!==''||!metrics.text)throw Error('Populated/narrow layout failed '+JSON.stringify(metrics));
  fs.writeFileSync(path.join(out,`${style}-${appearance}-${width}-populated.png`),(await win.webContents.capturePage()).toPNG());cases.push({style,appearance,width,populated:true,...metrics});
 }
 win.webContents.sendInputEvent({type:'keyDown',keyCode:',',modifiers:['control']});win.webContents.sendInputEvent({type:'keyUp',keyCode:',',modifiers:['control']});await wait(100);if(settings!==1)throw Error('Settings entry failed');
 fs.writeFileSync(path.join(out,'metrics.json'),JSON.stringify({host:process.platform,windowsNativeFrameVerified:false,cases},null,2));console.log('WINDOWS_RENDERER_LAYOUT_PASS 10 empty/populated/style/theme/width cases and menu-free settings shortcut');clearTimeout(timer);app.exit(0);
 }catch(error){console.error(error);app.exit(1);}});
