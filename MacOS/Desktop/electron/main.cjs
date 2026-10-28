const { app, BrowserWindow, ipcMain, protocol, net, dialog, Menu, nativeImage, screen, clipboard } = require('electron');
const { spawn } = require('node:child_process');
const { createInterface } = require('node:readline');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { cachedArtworkFile } = require('./artwork-files.cjs');

// The packaged channel controls identity before Chromium creates profiles/locks.
const {desktopIdentity} = require('./build-identity.cjs');
let channel = 'release';
if(app.isPackaged){try{channel=JSON.parse(fs.readFileSync(path.join(process.resourcesPath,'build-channel.json'),'utf8')).channel;}catch{}}
const identity=desktopIdentity(channel,app.getPath('appData'));
app.setName(identity.name);
app.setPath('userData',identity.userData);
if(identity.debug){app.setPath('sessionData',identity.userData);app.setAppLogsPath(path.join(app.getPath('home'),'Library','Logs',identity.name));}
if (!app.requestSingleInstanceLock()) app.exit(0);
app.on('second-instance', () => showMainWindow());

// The privileged shell brokers a narrow command protocol. The renderer has no
// filesystem/Node access, even while displaying local artwork and audio metadata.
protocol.registerSchemesAsPrivileged([{ scheme: 'minivoice-art', privileges: { standard: true, secure: true, supportFetchAPI: true } }]);
let window, engine, artworkRoot, lyricsWindow, lyricsUnlockWindow, quitting = false;
const {lyricsWindowState,lyricsUnlockBounds,lyricsUnlockWindowOptions}=require('./lyrics-window-state.cjs');
const lyricsFile=path.join(app.getPath('userData'),'own-desktop-lyrics.json');
let lyricsOptions=lyricsWindowState();try{lyricsOptions=lyricsWindowState(JSON.parse(fs.readFileSync(lyricsFile,'utf8')));}catch{}
function saveLyricsOptions(){fs.mkdirSync(path.dirname(lyricsFile),{recursive:true});fs.writeFileSync(lyricsFile,JSON.stringify(lyricsOptions));}
function lyricsState(data){return identity.debug?{...data,desktopLyrics:lyricsOptions.enabled,desktopLyricsLocked:lyricsOptions.locked,desktopLyricsFont:lyricsOptions.font,desktopLyricsVertical:lyricsOptions.vertical}:data;}
function refreshLyricsState(){const current=latest.get('state');if(current)emit('state',current);}
function syncLyricsUnlock(){
 if(!lyricsOptions.locked||!lyricsWindow||lyricsWindow.isDestroyed()) {lyricsUnlockWindow?.close();lyricsUnlockWindow=null;return;}
 const bounds=lyricsUnlockBounds(lyricsWindow.getBounds(),screen.getDisplayMatching(lyricsWindow.getBounds()).workArea,lyricsOptions.vertical);
 if(lyricsUnlockWindow&&!lyricsUnlockWindow.isDestroyed()){lyricsUnlockWindow.setBounds(bounds);return;}
 const target=new BrowserWindow({...lyricsUnlockWindowOptions(bounds),title:'解锁桌面歌词',webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,sandbox:true,nodeIntegration:false}});
 lyricsUnlockWindow=target;target.setVisibleOnAllWorkspaces(true,{visibleOnFullScreen:true});target.webContents.setWindowOpenHandler(()=>({action:'deny'}));target.webContents.on('will-navigate',event=>event.preventDefault());
 target.webContents.on('did-finish-load',()=>{for(const [event,data]of latest)target.webContents.send('engine:event',{event,data});});target.once('ready-to-show',()=>target.showInactive());target.on('closed',()=>{if(lyricsUnlockWindow===target)lyricsUnlockWindow=null;});
 target.loadFile(path.resolve(__dirname,'../dist/index.html'),{query:{surface:'desktopLyricsUnlock'}});
}
function createLyricsWindow(){
 if(!identity.debug||!lyricsOptions.enabled||lyricsWindow&&!lyricsWindow.isDestroyed())return;
 const bounds=lyricsOptions,valid=screen.getAllDisplays().some(display=>bounds.x!==null&&bounds.y!==null&&bounds.x+100>display.workArea.x&&bounds.x<display.workArea.x+display.workArea.width-100&&bounds.y+80>display.workArea.y&&bounds.y<display.workArea.y+display.workArea.height-30);
 lyricsWindow=new BrowserWindow({width:bounds.width,height:bounds.height,...(valid?{x:bounds.x,y:bounds.y}:{}),minWidth:bounds.vertical?100:360,minHeight:bounds.vertical?360:88,maxWidth:bounds.vertical?500:2000,maxHeight:bounds.vertical?1600:500,frame:false,transparent:true,alwaysOnTop:true,resizable:true,show:false,skipTaskbar:true,title:'MiniVoice-debug 桌面歌词',webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,sandbox:true,nodeIntegration:false}});
 const target=lyricsWindow;target.setVisibleOnAllWorkspaces(true,{visibleOnFullScreen:true});target.setIgnoreMouseEvents(lyricsOptions.locked,{forward:true});target.webContents.setWindowOpenHandler(()=>({action:'deny'}));target.webContents.on('will-navigate',event=>event.preventDefault());
 target.webContents.on('did-finish-load',()=>{for(const [event,data]of latest)target.webContents.send('engine:event',{event,data});});
 target.once('ready-to-show',()=>{target.showInactive();syncLyricsUnlock();});target.on('move',syncLyricsUnlock);target.on('resize',syncLyricsUnlock);target.on('close',()=>{const rect=target.getBounds();lyricsOptions=lyricsWindowState({...lyricsOptions,...rect});if(!quitting)lyricsOptions.enabled=false;saveLyricsOptions();});target.on('closed',()=>{lyricsUnlockWindow?.close();lyricsUnlockWindow=null;lyricsWindow=null;if(!quitting)refreshLyricsState();});
 target.loadFile(path.resolve(__dirname,'../dist/index.html'),{query:{surface:'desktopLyrics'}});
}
function toggleOwnLyrics(){lyricsOptions.enabled=!lyricsOptions.enabled;saveLyricsOptions();if(lyricsOptions.enabled)createLyricsWindow();else lyricsWindow?.close();refreshLyricsState();return lyricsOptions.enabled;}

function showMainWindow(){
  if(!window||window.isDestroyed())return;
  if(window.isMinimized())window.restore();
  window.show();window.focus();
}
const pending = new Map(), latest = new Map();
let engineRestarts = [], restartTimer;
const panelWindows=require('./panel-windows.cjs').createPanelWindows({BrowserWindow,screen,index:path.resolve(__dirname,'../dist/index.html'),preload:path.join(__dirname,'preload.cjs'),parent:()=>window,events:()=>latest,isQuitting:()=>quitting});
const artworkIO=require('./artwork-transfer.cjs').artworkTransfer({nativeImage,clipboard,resolveFile:src=>cachedArtworkFile(artworkRoot,src),directory:path.join(app.getPath('temp'),'MiniVoice-artwork-'+process.pid)});
const actions = new Set(['prepareOriginalArtwork','artworkSearch','artworkDownload','desktopSettings','desktopPreference','desktopShortcut','lyricsModel','sharedCore','portableSnapshot','sorting','tasks','deleteTracks','addManyToPlaylist','removeManyFromPlaylist','openSettings','openEditor','interfaceStyle','orderedTracks','lyricsPresentation','favoriteMany','appearance','snapshot','play','select','toggle','pause','seek','skip','volume','mode','favorite','rescan','removeFolder','recursive','createPlaylist','renamePlaylist','deletePlaylist','addToPlaylist','removeFromPlaylist','clearRecent','detail','reveal','desktopLyrics','outputDevice','clearError','lyricsSearch','syncLyrics','saveMetadata','removeTrack']);
const stateFile = () => path.join(app.getPath('userData'), 'window.json');
const packagedEngine = () => path.join(process.resourcesPath, 'Native', 'MiniVoice.app', 'Contents', 'MacOS', 'MiniVoice');
function request(action, payload = {}) {
  return new Promise((resolve, reject) => {
    if (!engine?.stdin.writable) return reject(new Error('播放后台未连接，请重新打开应用。'));
    const id = require('node:crypto').randomUUID();
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error('后台响应超时，请检查后台任务。')); }, ['artworkSearch','artworkDownload','lyricsSearch','saveMetadata'].includes(action) ? 180000 : 30000);
    pending.set(id, { resolve, reject, timeout });
    engine.stdin.write(JSON.stringify({ id, action, payload }) + '\n');
  });
}
function emit(event, data) {
  if(event==='uiSurface'&&['settings','editor'].includes(data?.type)){panelWindows.open(data);return;}
  if(event==='uiSurface')showMainWindow();
  if(event==='hostSurface'&&data?.type==='desktopLyrics'&&identity.debug){toggleOwnLyrics();return;}
  if(event==='state'){data=lyricsState(data);if(identity.debug&&lyricsOptions.enabled)createLyricsWindow();}
  latest.set(event, data);
  panelWindows.broadcast(event,data);
  if (window && !window.isDestroyed()) window.webContents.send('engine:event', { event, data });
  if(lyricsWindow&&!lyricsWindow.isDestroyed())lyricsWindow.webContents.send('engine:event',{event,data});
  if(lyricsUnlockWindow&&!lyricsUnlockWindow.isDestroyed())lyricsUnlockWindow.webContents.send('engine:event',{event,data});
}
function logEngine(message) {
  try { fs.mkdirSync(app.getPath('logs'), { recursive: true }); fs.appendFileSync(path.join(app.getPath('logs'), 'audio-engine.log'), `${new Date().toISOString()} ${message}\n`); } catch {}
}
function startEngine() {
  const executable = process.env.MINIVOICE_ENGINE || (app.isPackaged ? packagedEngine() : path.resolve(__dirname, '../../../.build/native/MiniVoice.app/Contents/MacOS/MiniVoice'));
  engine = spawn(executable, ['--desktop-engine'], { stdio: ['pipe','pipe','pipe'], env: { ...process.env } });
  const child = engine;
  child.stderr.on('data', bytes => { process.stderr.write(bytes); logEngine(bytes.toString().trim()); });
  const reader = createInterface({ input: engine.stdout });
  reader.on('line', line => {
    let message; try { message = JSON.parse(line); } catch { return; }
    if (message.id) {
      const item = pending.get(message.id); if (!item) return;
      clearTimeout(item.timeout); pending.delete(message.id);
      if (message.error) item.reject(new Error(message.error)); else item.resolve(message.result);
    } else if (message.event) {
      if (message.event === 'ready') {
        artworkRoot = message.data.artworkRoot;
        if (engineRestarts.length) { logEngine('后台重新连接'); emit('engineError', '播放后台已重新连接，可以继续播放。'); }
      }
      if (message.event === 'shell') {
        if (message.data === 'quit') app.quit();
        else if (message.data === 'toggleWindow' && window?.isVisible() && window?.isFocused()) window.hide();
        else if (['showWindow','focusWindow','toggleWindow'].includes(message.data)) { showMainWindow(); app.focus({ steal: true }); }
      } else emit(message.event, message.data);
    }
  });
  const fail = message => {
    for (const item of pending.values()) { clearTimeout(item.timeout); item.reject(new Error(message)); }
    pending.clear(); if (!quitting) emit('engineError', message);
  };
  child.on('error', error => { logEngine(error.stack || error.message); fail(error.message); });
  child.on('exit', (code, signal) => {
    if (engine !== child) return;
    logEngine(`后台退出 code=${code} signal=${signal || 'none'} quitting=${quitting}`);
    fail('播放后台连接中断，正在重新连接…');
    if (quitting) return;
    const now = Date.now(); engineRestarts = engineRestarts.filter(time => now-time < 60000);
    if (engineRestarts.length >= 3) { emit('engineError', '播放后台连续退出，请重新打开应用。诊断已保存在音频后台日志中。'); return; }
    engineRestarts.push(now);
    restartTimer = setTimeout(() => { restartTimer = undefined; if (!quitting) startEngine(); }, 300);
  });
}
function createWindow() {
  let bounds = { width: 1280, height: 820 };
  try { const saved = JSON.parse(fs.readFileSync(stateFile())); if (Number.isFinite(saved.width) && Number.isFinite(saved.height) && saved.width >= 304 && saved.height >= 600) bounds = saved; } catch {}
  window = new BrowserWindow({ ...bounds, minWidth: 304, minHeight: 600, show: false,
    title: identity.name, titleBarStyle: 'hiddenInset', trafficLightPosition: { x: 9, y: 9 },
    // The renderer draws its own glass over artwork. An additional AppKit
    // visual-effect surface needlessly recomposites the whole window on resize.
    backgroundColor: '#111615',
    webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: false } });
  window.webContents.on('page-title-updated',event=>{if(identity.debug){event.preventDefault();window.setTitle(identity.name);}});
  const index = path.resolve(__dirname, '../dist/index.html');
  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  window.webContents.on('will-navigate', (event, url) => { if (url !== pathToFileURL(index).href) event.preventDefault(); });
  window.webContents.on('did-finish-load', () => { for (const [event, data] of latest) window.webContents.send('engine:event', { event, data }); });
  window.on('close', event => {
    try { if (!window.isFullScreen()) fs.writeFileSync(stateFile(), JSON.stringify(window.getNormalBounds())); } catch {}
    if (!quitting && process.platform === 'darwin') {
      event.preventDefault();
      const behavior = latest.get('state')?.closeBehavior;
      if (behavior === 'quit') app.quit();
      else { if (behavior === 'pause') request('pause').catch(error => emit('engineError', error.message)); window.hide(); }
    }
  });
  window.once('ready-to-show', () => window.show());
  window.loadFile(index);
}
app.whenReady().then(() => {
  const originalRequests=new Map(),verifiedOriginals=new Set();
  protocol.handle('minivoice-art', async resource => {
    const url=new URL(resource.url),key=url.pathname.slice(1);
    if(artworkRoot&&url.hostname==='detail'&&/^[0-9a-f]{64}$/.test(key)&&(!verifiedOriginals.has(key)||!fs.existsSync(path.join(artworkRoot,'Artwork','Original',key)))){
      if(!originalRequests.has(key))originalRequests.set(key,request('prepareOriginalArtwork',{key}).then(value=>{if(value===true)verifiedOriginals.add(key);return value;}).catch(()=>null).finally(()=>originalRequests.delete(key)));
      await originalRequests.get(key);
    }
    const file = cachedArtworkFile(artworkRoot, resource.url);
    return file ? net.fetch(pathToFileURL(file).href) : new Response('', { status: 404 });
  });
  ipcMain.handle('engine:command', async (event, { action, payload = {} } = {}) => {
    if ((!panelWindows.owns(event.sender)&&![window,lyricsWindow,lyricsUnlockWindow].some(target=>target&&!target.isDestroyed()&&event.sender===target.webContents))||event.senderFrame!==event.sender.mainFrame) throw new Error('无效的界面来源');
    if(event.sender===lyricsUnlockWindow?.webContents&&!(action==='snapshot'||action==='desktopLyricsConfig'&&payload?.locked===false&&Object.keys(payload).length===1))throw Error('无效的解锁操作');
    if(action==='panelClose'){if(!panelWindows.owns(event.sender))throw Error('无效的编辑窗口');panelWindows.close(event.sender);return true;}
    if(['copyEditorArtwork','pasteEditorArtwork'].includes(action)){if(!panelWindows.owns(event.sender))throw Error('请在歌曲编辑窗口操作');return action==='copyEditorArtwork'?artworkIO.copy(payload.src):artworkIO.paste();}
    if(identity.debug&&action==='desktopLyrics')return toggleOwnLyrics();
    if(identity.debug&&action==='desktopLyricsConfig'){
      if(!payload||typeof payload!=='object'||Object.keys(payload).some(key=>!['locked','font','vertical'].includes(key))||('locked'in payload&&typeof payload.locked!=='boolean')||('font'in payload&&!Number.isFinite(payload.font))||('vertical'in payload&&typeof payload.vertical!=='boolean'))throw Error('无效的桌面歌词配置');
      let resize=null;if('vertical'in payload&&payload.vertical!==lyricsOptions.vertical){const old=lyricsWindow?.getBounds()||{...lyricsOptions,x:lyricsOptions.x??0,y:lyricsOptions.y??0},area=screen.getDisplayMatching(old).workArea;resize=lyricsWindowState({...lyricsOptions,...payload,width:old.height,height:old.width});resize.width=Math.min(resize.width,area.width);resize.height=Math.min(resize.height,area.height);resize.x=Math.round(Math.max(area.x,Math.min(area.x+area.width-resize.width,(old.x??area.x)+old.width/2-resize.width/2)));resize.y=Math.round(Math.max(area.y,Math.min(area.y+area.height-resize.height,(old.y??area.y)+old.height/2-resize.height/2)));}
      lyricsOptions=resize||lyricsWindowState({...lyricsOptions,...payload});if(resize&&lyricsWindow){lyricsWindow.setMinimumSize(resize.vertical?100:360,resize.vertical?360:88);lyricsWindow.setMaximumSize(resize.vertical?500:2000,resize.vertical?1600:500);lyricsWindow.setBounds({x:resize.x,y:resize.y,width:resize.width,height:resize.height},true);}saveLyricsOptions();lyricsWindow?.setIgnoreMouseEvents(lyricsOptions.locked,{forward:true});syncLyricsUnlock();refreshLyricsState();return true;
    }
    if(identity.debug&&['pickEditorArtwork','pickEditorLyrics'].includes(action)){
      if(!panelWindows.owns(event.sender))throw Error('请在歌曲编辑窗口操作');
      const image=action==='pickEditorArtwork';const selected=await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender),{title:image?'选择歌曲封面':'导入歌词',properties:['openFile'],filters:[{name:image?'图片':'歌词',extensions:image?['png','jpg','jpeg','webp']:['lrc','txt']}]});if(selected.canceled)return null;
      const file=selected.filePaths[0],stat=fs.statSync(file);if(!stat.isFile()||stat.size>(image?20*1024*1024:1024*1024))throw Error('文件过大');
      if(image){const bitmap=nativeImage.createFromPath(file);if(bitmap.isEmpty())throw Error('无法读取图片');const bytes=fs.readFileSync(file),extension=path.extname(file).toLowerCase(),mime=extension==='.png'?'image/png':extension==='.webp'?'image/webp':'image/jpeg';return 'data:'+mime+';base64,'+bytes.toString('base64');}
      let bytes=fs.readFileSync(file);if(bytes[0]===0xff&&bytes[1]===0xfe)return bytes.subarray(2).toString('utf16le');if(bytes[0]===0xfe&&bytes[1]===0xff)return bytes.subarray(2).swap16().toString('utf16le');return new TextDecoder('utf-8',{fatal:true}).decode(bytes).replace(/^\uFEFF/,'');
    }
    if (action === 'captureStyle') {
      const image = await window.webContents.capturePage();
      return image.resize({ width: Math.min(1000, image.getSize().width) }).toDataURL();
    }
    if (action === 'chooseFolders') {
      const selected = await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender), { title: '添加音乐文件夹', properties: ['openDirectory','multiSelections'] });
      return selected.canceled ? false : request('addFolders', { paths: selected.filePaths });
    }
    if (action === 'window') {
      if (payload.action === 'show') showMainWindow();
      if (payload.action === 'minimize') window.minimize();
      if (payload.action === 'fullscreen') window.setFullScreen(!window.isFullScreen());
      return true;
    }
    if (action === 'portableExit') { await window.loadFile(path.resolve(__dirname, '../dist/index.html')); return true; }
    if (action === 'quit') { app.quit(); return true; }
    if (!actions.has(action) || !require('./command-payload.cjs').validCommandPayload(action,payload)) throw new Error('无效的后台命令');
    return request(action, payload);
  });
  ipcMain.on('editor:dragArtwork',(event,src)=>{if(!panelWindows.owns(event.sender)||event.senderFrame!==event.sender.mainFrame)return;try{artworkIO.drag(event.sender,src);}catch(error){event.sender.send('engine:event',{event:'error',data:error.message});}});
  const menuAction = (action, payload) => request(action, payload).catch(error => emit('engineError', error.message));
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    { label: identity.name, submenu: [identity.debug?{label:'关于 MiniVoice-debug',click:()=>emit('uiSurface',{type:'about'})}:{role:'about'}, { type: 'separator' }, { label: '设置…', accelerator: 'Cmd+,', click: () => menuAction('openSettings') }, { role: 'hide' }, { role: 'hideOthers' }, { type: 'separator' }, { role: 'quit' }] },
    { role: 'editMenu' },
    { label: '播放', submenu: [{ label: '播放 / 暂停', click: () => menuAction('toggle') }, { label: '上一首', click: () => menuAction('skip', { delta: -1 }) }, { label: '下一首', click: () => menuAction('skip', { delta: 1 }) }] },
    { label: '显示', submenu: [...(identity.debug?[{label:'自有组件设置…',click:()=>menuAction('openSettings')}]:[]), { role: 'togglefullscreen' }, { label: '简易样式', click: () => emit('style','simple') }, { label: '音乐库样式', click: () => emit('style','library') }, { label: '音乐墙样式', click: () => emit('style','wall') }] },
    { role: 'windowMenu' }
  ]));
  createWindow(); startEngine();
  app.on('activate', () => { if (!window || window.isDestroyed()) createWindow(); else showMainWindow(); });
});
app.on('window-all-closed', () => app.quit());
app.on('before-quit', event => {
  if (quitting) return;
  event.preventDefault(); quitting = true; clearTimeout(restartTimer);
  artworkIO.cleanup();
  // Persist the native playback position before terminating the child process.
  Promise.race([request('pause').catch(() => {}), new Promise(resolve => setTimeout(resolve, 1500))])
    .finally(() => { if (engine && engine.exitCode === null) engine.kill('SIGTERM'); app.quit(); });
});
app.on('will-quit', () => { if (engine && engine.exitCode === null) engine.kill('SIGTERM'); });
