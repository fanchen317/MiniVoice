const {app,BrowserWindow,ipcMain,dialog,protocol,net,shell,Menu,Tray,screen,globalShortcut}=require('electron');
const fs=require('node:fs/promises'),path=require('node:path'),{pathToFileURL}=require('node:url'),{spawn}=require('node:child_process'),{scan}=require('./library.cjs');
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true}},{scheme:'mv-audio',privileges:{standard:true,secure:true,supportFetchAPI:true,stream:true}}]);
let tray,quitting=false;
let window,state={version:1,folders:[],songs:[],favorites:[],playlists:[],recent:[],queue:[],current:'',position:0,mode:1,workspace:{version:1,pages:{}}},playing=false,scanning=false,audioError='',writes=Promise.resolve(),core;
const {collectionAction}=require('./collections.cjs');
const pending=[];
function coreRequest(request){return new Promise((resolve,reject)=>{if(!core)return reject(new Error('共享核心不可用'));pending.push({resolve,reject});core.stdin.write(JSON.stringify({...request,version:1})+'\n');});}
function save(){const data=JSON.stringify(state);writes=writes.catch(()=>{}).then(async()=>{const target=path.join(app.getPath('userData'),'state.json');await fs.writeFile(target+'.tmp',data);await fs.rename(target+'.tmp',target);});return writes;}
async function rescan(){if(scanning)throw Error('正在扫描');scanning=true;state.importing=true;try{const songs=await scan(state.folders,{recursive:state.recursive!==false,excluded:state.excluded||[],previous:state.songs,metadata:file=>require('./metadata.cjs').readMetadata(file,{cacheDir:path.join(app.getPath('cache'),'MiniVoice','Artwork')}),onProgress:progress=>{state.scanSummary=`已扫描 ${progress.count} 首`;}});state.songs=songs;const ids=new Set(songs.map(s=>s.id));state.queue=state.queue.filter(id=>ids.has(id));if(!ids.has(state.current)){state.current='';state.position=0;playing=false;}await save();}finally{scanning=false;state.importing=false;}}
function playback(){return {value:true,audio:{id:state.current,position:state.position,playing}};}
function select(id,ids){if(!state.songs.some(s=>s.id===id))throw Error('歌曲已不在授权音乐库内');if(ids){if(!Array.isArray(ids)||ids.some(id=>!state.songs.some(s=>s.id===id)))throw Error('无效队列');state.queue=[...new Set(ids)];}state.current=id;state.position=0;state.recent=[id,...state.recent.filter(x=>x!==id)].slice(0,200);}
async function request(r){if(!r||r.version!==1||JSON.stringify(r).length>4*1024*1024)throw Error('无效协议');const p=r.payload||{};
 switch(r.kind){
 case 'core':return coreRequest(r.request);
 case 'readState':return state.workspace;
 case 'writeState':state.workspace=r.state;await save();return true;
 case 'snapshot':return {value:{...state,playing,scanning,rawLyrics:await lyrics(state.current),error:audioError},audio:{id:state.current,position:state.position,playing}};
 case 'play':select(r.id,r.ids);playing=true;await save();return playback();
 case 'pause':playing=false;await save();return playback();
 case 'toggle':if(!state.current)throw Error('请先选择歌曲');playing=!playing;await save();return playback();
 case 'seek':if(!Number.isFinite(r.position))throw Error('无效进度');state.position=Math.max(0,r.position);await save();return playback();
 case 'skip':{let ids=state.queue.length?state.queue:state.songs.map(s=>s.id),index=ids.indexOf(state.current);if(!ids.length)return true;if(r.ended&&[0,1].includes(state.mode)&&(state.mode===0||index===ids.length-1)){playing=false;state.position=0;return playback();}if(r.delta<0&&!r.ended&&state.position>3000){state.position=0;await save();return playback();}if(!(r.ended&&state.mode===3)){index=state.mode===2?ids.indexOf(require('./shuffle.cjs').shuffleNext(state,ids,r.delta)):(index+(r.delta<0?-1:1)+ids.length)%ids.length;select(ids[index]);}else state.position=0;await save();return playback();}
 case 'exit':app.quit();return true;
 case 'action':switch(r.name){
 case 'createPlaylist':case 'renamePlaylist':case 'deletePlaylist':case 'addManyToPlaylist':case 'removeManyFromPlaylist':case 'favoriteMany':{const result=collectionAction(state,r.name,p);await save();return result;}
 case 'getSettings':return {folders:state.folders.map(folder=>({id:folder,path:folder,name:path.basename(folder)})),actions:['chooseFolder','removeFolder','rescan','clearRecent'],recursive:true};
 case 'chooseFolder':{const result=await dialog.showOpenDialog(window,{properties:['openDirectory']});if(!result.canceled){const folder=await fs.realpath(result.filePaths[0]);if(!state.folders.includes(folder))state.folders.push(folder);await rescan();}return true;}
 case 'removeFolder':state.folders=state.folders.filter(f=>f!==p.folder);await rescan();return playback();
 case 'recursive':state.recursive=Boolean(p.value);await rescan();return playback();
 case 'rescan':await rescan();return playback();
 case 'clearRecent':state.recent=[];break;
 case 'mode':if(!Number.isInteger(p.value)||p.value<0||p.value>4)throw Error('无效模式');state.mode=p.value;break;
 case 'queueSelect':select(p.id);playing=true;await save();return playback();
 case 'readLyrics':return {raw:await lyrics(p.id)};
 case 'favorite':if(!state.songs.some(s=>s.id===p.id))throw Error('无效歌曲');state.favorites=state.favorites.includes(p.id)?state.favorites.filter(id=>id!==p.id):[...state.favorites,p.id];break;
 default:throw Error('Windows 尚未接入此能力：'+r.name);
 }await save();return true;
 default:throw Error('未知命令');}}
async function lyrics(id){const song=state.songs.find(s=>s.id===id);if(!song)return '';if(song.rawLyrics)return song.rawLyrics;try{return await fs.readFile(song.path.slice(0,-path.extname(song.path).length)+'.lrc','utf8');}catch(e){if(e.code==='ENOENT')return '';throw e;}}
app.whenReady().then(async()=>{
 try{state={...state,...JSON.parse(await fs.readFile(path.join(app.getPath('userData'),'state.json'),'utf8'))};}catch(e){if(e.code!=='ENOENT')throw e;}
 const binary=path.join(app.isPackaged?path.join(process.resourcesPath,'app.asar.unpacked'):path.join(__dirname,'..'),'resources','minivoice-core'+(process.platform==='win32'?'.exe':''));core=spawn(binary,[],{windowsHide:true,stdio:['pipe','pipe','pipe']});let buffer='';core.stderr.resume();core.stdin.on('error',()=>{});core.stdout.setEncoding('utf8');core.stdout.on('data',chunk=>{buffer+=chunk;let i;while((i=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,i);buffer=buffer.slice(i+1);const job=pending.shift();if(job)try{const result=JSON.parse(line);result.ok?job.resolve(result.value):job.reject(Error(result.error));}catch(e){job.reject(e);}}});const fail=error=>{core=null;for(const job of pending.splice(0))job.reject(error);};core.on('error',fail);core.on('exit',()=>fail(Error('共享核心已退出')));
 protocol.handle('minivoice-art',async req=>{const u=new URL(req.url),key=u.pathname.slice(1);if(!['cover','detail'].includes(u.hostname)||! /^[a-f0-9]{64}$/.test(key)||!state.songs.some(song=>song.artworkKey===key))return new Response('',{status:403});try{const data=await fs.readFile(path.join(app.getPath('cache'),'MiniVoice','Artwork',key));return new Response(data,{headers:{'Content-Type':state.songs.find(song=>song.artworkKey===key).artworkMime,'Cache-Control':'private, max-age=3600'}});}catch{return new Response('',{status:404});}});
 protocol.handle('mv-audio',async req=>{const u=new URL(req.url),song=state.songs.find(s=>s.id===u.pathname.slice(1));if(u.hostname!=='song'||!song)return new Response('',{status:403});const real=await fs.realpath(song.path);if(!state.folders.some(root=>{const rel=path.relative(root,real);return rel!== '..'&&!rel.startsWith('..'+path.sep)&&!path.isAbsolute(rel);}))return new Response('',{status:403});return net.fetch(pathToFileURL(real).href,{headers:req.headers});});
 const windowHotkey=require('./window-shortcut.cjs').windowShortcut({globalShortcut,toggle:()=>{if(window.isVisible()&&window.isFocused())window.hide();else{window.show();window.focus();}}});app.once('will-quit',()=>windowHotkey.dispose());
 const controlAudio=require('./audio-control.cjs').audioControl({ipcMain,getWindow:()=>window});
 const desktop=require('./desktop.cjs').desktopHost({app,BrowserWindow,dialog,shell,audioControl:controlAudio,windowShortcut:windowHotkey,getState:()=>state,request,save,lyrics,coreRequest,getWindow:()=>window,getPlaying:()=>playing});
 const bounds=state.windowBounds;const visible=bounds&&screen.getAllDisplays().some(d=>bounds.x<d.workArea.x+d.workArea.width&&bounds.x+bounds.width>d.workArea.x&&bounds.y<d.workArea.y+d.workArea.height&&bounds.y+bounds.height>d.workArea.y);
 window=new BrowserWindow({...(visible?bounds:{width:1200,height:800}),minWidth:560,minHeight:400,webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:false}});
 window.on('resize',()=>{state.windowBounds=window.getBounds();save().catch(console.error);});window.on('move',()=>{state.windowBounds=window.getBounds();save().catch(console.error);});window.on('close',event=>{if(!quitting&&state.closeBehavior&&state.closeBehavior!=='quit'){event.preventDefault();if(state.closeBehavior==='pause'){playing=false;window.webContents.send('audio',playback());}window.hide();save().catch(console.error);}});
 tray=new Tray(path.join(__dirname,'..','ui','app-icon.png'));tray.setToolTip('MiniVoice');tray.on('double-click',()=>{window.show();window.focus();});tray.setContextMenu(Menu.buildFromTemplate([{label:'打开 MiniVoice',click:()=>{window.show();window.focus();}},{label:'播放 / 暂停',click:()=>desktop.command('toggle').catch(console.error)},{label:'退出',click:()=>app.quit()}]));
 if(state.windowShortcut)try{windowHotkey.register(state.windowShortcut);}catch(error){audioError=error.message;}
 const trusted=e=>{if(e.sender!==window.webContents||e.senderFrame!==window.webContents.mainFrame)throw Error('非法来源');};
 ipcMain.on('editor:dragArtwork',(event,src)=>{if(BrowserWindow.getAllWindows().some(w=>w.webContents===event.sender)&&event.senderFrame===event.sender.mainFrame)desktop.command('dragEditorArtwork',{src},event.sender).catch(error=>event.sender.send('engine:event',{event:'error',data:error.message}));});
 ipcMain.handle('engine:command',async(e,{action,payload})=>{if(!BrowserWindow.getAllWindows().some(w=>w.webContents===e.sender)||e.senderFrame!==e.sender.mainFrame)throw Error('非法来源');return desktop.command(action,payload,e.sender);});
 ipcMain.handle('request',(e,r)=>{trusted(e);return request(r);});ipcMain.handle('clock',(e,value)=>{trusted(e);if(value.id===state.current&&Number.isFinite(value.position)){state.position=Math.max(0,value.position);playing=Boolean(value.playing);const song=state.songs.find(s=>s.id===value.id);if(song&&Number.isFinite(value.duration))song.duration=value.duration;desktop.emit('clock',{time:state.position/1000,duration:value.duration/1000,playing});return save();}});ipcMain.handle('audio-error',(e,message)=>{trusted(e);playing=false;audioError=String(message);});
 window.webContents.session.webRequest.onHeadersReceived((details,callback)=>callback({responseHeaders:{...details.responseHeaders,'Content-Security-Policy':["default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' minivoice-art: data: blob:; media-src mv-audio:; connect-src 'self'; object-src 'none'; base-uri 'none'"]}}));
 window.webContents.setWindowOpenHandler(()=>({action:'deny'}));window.webContents.on('will-navigate',e=>e.preventDefault());await window.loadFile(path.join(__dirname,'..','ui','index.html'));Menu.setApplicationMenu(Menu.buildFromTemplate([{label:'MiniVoice',submenu:[{label:'设置',click:()=>desktop.command('openSettings').catch(console.error)},{label:'解锁桌面歌词',click:()=>desktop.command('desktopLyricsConfig',{locked:false}).catch(console.error)},{type:'separator'},{role:'quit'}]},{label:'编辑',submenu:[{role:'undo'},{role:'redo'},{type:'separator'},{role:'cut'},{role:'copy'},{role:'paste'},{role:'selectAll'}]}]));await desktop.publish(true);const timer=setInterval(()=>desktop.publish().catch(console.error),1000);window.on('closed',()=>clearInterval(timer));
});
app.on('before-quit',()=>{quitting=true;});
app.on('window-all-closed',()=>app.quit());app.on('will-quit',()=>core?.kill());
