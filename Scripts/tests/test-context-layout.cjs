const {app,BrowserWindow}=require('electron');const assert=require('node:assert/strict');const wait=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{let w;try{
 w=new BrowserWindow({show:false,width:920,height:760,webPreferences:{backgroundThrottling:false,partition:'context-layout-'+Date.now()}});const js=s=>w.webContents.executeJavaScript(s,true);await w.loadURL('http://127.0.0.1:5194/tests/wall-desktop.html');await wait(800);
 const geometry=()=>js(`Object.fromEntries(['.sidebar','.workspace','.player','.window-tools'].map(selector=>{const n=document.querySelector(selector),r=n.getBoundingClientRect();return [selector,[r.x,r.y,r.width,r.height].map(v=>Math.round(v*100)/100)]}))`);
 for(const style of ['simple','library'])for(const theme of ['light','dark'])for(const width of [920,600,360]){
  w.setContentSize(width,760);await js(`window.desktopWallFixture.state.interfaceStyle='${style}';window.desktopWallFixture.theme('${theme}')`);await wait(550);
  if(!await js(`document.querySelector('.app').classList.contains('with-sidebar')`)){await js(`document.querySelector('.window-tools button').click()`);await wait(600);}
  const before=await geometry();
  await js(`(()=>{const row=[...document.querySelectorAll('.track-row')].find(n=>n.getClientRects().length);if(!row)throw Error('No song row');window.contextOrigin=row;row.dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true,clientX:innerWidth-10,clientY:innerHeight-15}))})()`);await wait(100);
  assert.deepEqual(await geometry(),before,style+' '+theme+' '+width+': opening context menu moves layout');
  assert.ok(await js(`(()=>{const n=document.querySelector('[data-mv-menu=popover]'),r=n.getBoundingClientRect();return !document.querySelector('.app').contains(n)&&r.left>=7&&r.top>=7&&r.right<=innerWidth-7&&r.bottom<=innerHeight-7})()`),'Menu must have its own viewport layer and fit screen');
  w.webContents.sendInputEvent({type:'keyDown',keyCode:'Escape'});w.webContents.sendInputEvent({type:'keyUp',keyCode:'Escape'});await wait(100);assert.deepEqual(await geometry(),before,'Closing menu moves layout');assert.ok(await js(`!document.querySelector('[data-mv-menu=popover]')&&document.activeElement===window.contextOrigin`));
 }
 console.log('PASS context menu leaves sidebar/workspace/player/tools fixed in simple/library, light/dark, 920/600/360px; viewport clamp and Escape focus restore');w.destroy();app.exit(0);
 }catch(e){console.error(e);w?.destroy();app.exit(1)}});
