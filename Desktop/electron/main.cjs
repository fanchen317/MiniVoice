const { app, BrowserWindow, ipcMain, protocol, net, dialog, Menu } = require('electron');
const { spawn } = require('node:child_process');
const { createInterface } = require('node:readline');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

// The privileged shell brokers a narrow command protocol. The renderer has no
// filesystem/Node access, even while displaying local artwork and audio metadata.
protocol.registerSchemesAsPrivileged([{ scheme: 'minivoice-art', privileges: { standard: true, secure: true, supportFetchAPI: true } }]);
let window, engine, artworkRoot, quitting = false;
const pending = new Map(), latest = new Map();
let engineRestarts = [], restartTimer;
const actions = new Set(['openSettings','openEditor','interfaceStyle','orderedTracks','lyricsPresentation','favoriteMany','appearance','snapshot','play','select','toggle','pause','seek','skip','volume','mode','favorite','rescan','removeFolder','recursive','createPlaylist','renamePlaylist','deletePlaylist','addToPlaylist','removeFromPlaylist','clearRecent','detail','reveal','desktopLyrics','outputDevice','clearError','lyricsSearch','syncLyrics','saveMetadata','removeTrack']);
const stateFile = () => path.join(app.getPath('userData'), 'window.json');
const packagedEngine = () => path.join(process.resourcesPath, 'Native', 'MiniVoice.app', 'Contents', 'MacOS', 'MiniVoice');
function request(action, payload = {}) {
  return new Promise((resolve, reject) => {
    if (!engine?.stdin.writable) return reject(new Error('播放后台未连接，请重新打开应用。'));
    const id = require('node:crypto').randomUUID();
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error('后台响应超时，请检查后台任务。')); }, ['lyricsSearch','saveMetadata'].includes(action) ? 180000 : 30000);
    pending.set(id, { resolve, reject, timeout });
    engine.stdin.write(JSON.stringify({ id, action, payload }) + '\n');
  });
}
function emit(event, data) {
  latest.set(event, data);
  if (window && !window.isDestroyed()) window.webContents.send('engine:event', { event, data });
}
function logEngine(message) {
  try { fs.mkdirSync(app.getPath('logs'), { recursive: true }); fs.appendFileSync(path.join(app.getPath('logs'), 'audio-engine.log'), `${new Date().toISOString()} ${message}\n`); } catch {}
}
function startEngine() {
  const executable = process.env.MINIVOICE_ENGINE || (app.isPackaged ? packagedEngine() : path.resolve(__dirname, '../../.build/MiniVoice.app/Contents/MacOS/MiniVoice'));
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
        else if (['showWindow','focusWindow','toggleWindow'].includes(message.data)) { window?.show(); app.focus({ steal: true }); }
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
    title: 'MiniVoice · Electron', titleBarStyle: 'hiddenInset', trafficLightPosition: { x: 9, y: 9 },
    // The renderer draws its own glass over artwork. An additional AppKit
    // visual-effect surface needlessly recomposites the whole window on resize.
    backgroundColor: '#111615',
    webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: false } });
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
  protocol.handle('minivoice-art', async request => {
    const url = new URL(request.url), key = url.pathname.slice(1), detail = url.hostname === 'detail';
    if (!artworkRoot || !/^[0-9a-f]{64}$/.test(key)) return new Response('', { status: 404 });
    const roots = detail ? ['Detail','Browse','List'] : ['Browse','List'];
    for (const kind of roots) {
      const file = path.join(artworkRoot, 'Artwork', kind, key);
      if (fs.existsSync(file)) return net.fetch(pathToFileURL(file).href);
    }
    return new Response('', { status: 404 });
  });
  ipcMain.handle('engine:command', async (event, { action, payload = {} } = {}) => {
    if (event.sender !== window?.webContents || event.senderFrame !== window?.webContents.mainFrame) throw new Error('无效的界面来源');
    if (action === 'captureStyle') {
      const image = await window.webContents.capturePage();
      return image.resize({ width: Math.min(1000, image.getSize().width) }).toDataURL();
    }
    if (action === 'chooseFolders') {
      const selected = await dialog.showOpenDialog(window, { title: '添加音乐文件夹', properties: ['openDirectory','multiSelections'] });
      return selected.canceled ? false : request('addFolders', { paths: selected.filePaths });
    }
    if (action === 'window') {
      if (payload.action === 'minimize') window.minimize();
      if (payload.action === 'fullscreen') window.setFullScreen(!window.isFullScreen());
      return true;
    }
    if (action === 'quit') { app.quit(); return true; }
    if (!actions.has(action) || !payload || typeof payload !== 'object' || JSON.stringify(payload).length > 4 * 1024 * 1024) throw new Error('无效的后台命令');
    return request(action, payload);
  });
  const menuAction = (action, payload) => request(action, payload).catch(error => emit('engineError', error.message));
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    { label: 'MiniVoice', submenu: [{ role: 'about' }, { type: 'separator' }, { label: '设置…', accelerator: 'Cmd+,', click: () => menuAction('openSettings') }, { role: 'hide' }, { role: 'hideOthers' }, { type: 'separator' }, { role: 'quit' }] },
    { role: 'editMenu' },
    { label: '播放', submenu: [{ label: '播放 / 暂停', click: () => menuAction('toggle') }, { label: '上一首', click: () => menuAction('skip', { delta: -1 }) }, { label: '下一首', click: () => menuAction('skip', { delta: 1 }) }] },
    { label: '显示', submenu: [{ role: 'togglefullscreen' }, { label: '简易样式', click: () => emit('style','simple') }, { label: '音乐库样式', click: () => emit('style','library') }, { label: '音乐墙样式', click: () => emit('style','wall') }] },
    { role: 'windowMenu' }
  ]));
  createWindow(); startEngine();
  app.on('activate', () => { if (!window || window.isDestroyed()) createWindow(); else window.show(); });
});
app.on('window-all-closed', () => app.quit());
app.on('before-quit', event => {
  if (quitting) return;
  event.preventDefault(); quitting = true; clearTimeout(restartTimer);
  // Persist the native playback position before terminating the child process.
  Promise.race([request('pause').catch(() => {}), new Promise(resolve => setTimeout(resolve, 1500))])
    .finally(() => { if (engine && engine.exitCode === null) engine.kill('SIGTERM'); app.quit(); });
});
app.on('will-quit', () => { if (engine && engine.exitCode === null) engine.kill('SIGTERM'); });
