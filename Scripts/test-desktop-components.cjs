// Run with the repository's Electron binary against the isolated Vite component fixture.
const {app,BrowserWindow}=require('electron');
const fs=require('node:fs');
const path=require('node:path');
let win;const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const check=(condition,message)=>{if(!condition)throw Error(message);};
async function js(source){return win.webContents.executeJavaScript(source,true);}
async function key(keyCode){win.webContents.sendInputEvent({type:'keyDown',keyCode});win.webContents.sendInputEvent({type:'keyUp',keyCode});await sleep(80);}
const timeout=setTimeout(()=>{process.stderr.write('Component test timed out\n');app.exit(1);},30000);
app.whenReady().then(async()=>{
 try{
  win=new BrowserWindow({show:false,width:900,height:700,webPreferences:{nodeIntegration:false,contextIsolation:true}});
  await win.loadURL(process.env.MINIVOICE_COMPONENT_URL||'http://127.0.0.1:5178/tests/components.html');await sleep(450);
  await js("document.querySelector('#launch').click()");await sleep(150);
  check(await js("(()=>{const r=document.querySelector('[data-mv-menu=popover]').getBoundingClientRect();return r.right<=innerWidth-7&&r.bottom<=innerHeight-7&&r.top>=8})()"),'Menu clipped by viewport');
  check(await js("document.activeElement.textContent==='播放'"),'Menu did not focus first action');
  await key('Down');check(await js("document.activeElement.textContent==='加入歌单'"),'Menu did not skip disabled action');
  await key('End');check(await js("document.activeElement.textContent==='删除歌曲'"),'Menu End did not choose last action');
  await key('Down');check(await js("document.activeElement.textContent==='播放'"),'Menu did not wrap');
  await key('Escape');check(await js("!document.querySelector('[data-mv-menu]')&&document.activeElement.id==='launch'"),'Menu Escape did not restore trigger');
  await js("document.querySelector('#launch').click()");await sleep(100);await key('Down');await key('Enter');
  check(await js("document.querySelector('#chosen').textContent==='加入歌单'&&!document.querySelector('[data-mv-menu]')"),'Menu Enter action failed');
  const rect=await js("(()=>{const r=document.querySelector('[role=slider]').getBoundingClientRect();return {x:Math.round(r.x),y:Math.round(r.y+r.height/2),width:Math.round(r.width)}})()");
  win.webContents.sendInputEvent({type:'mouseDown',x:rect.x+Math.round(rect.width*.25),y:rect.y,button:'left',clickCount:1});
  win.webContents.sendInputEvent({type:'mouseMove',x:rect.x+Math.round(rect.width*.75),y:rect.y,modifiers:['leftButtonDown']});await sleep(120);
  await js("document.querySelector('#reset').click()");await sleep(100);
  check(await js("Number(document.querySelector('[role=slider]').getAttribute('aria-valuenow'))>=74&&document.querySelector('#commits').textContent==='0'"),'Held slider moved or committed before release');
  win.webContents.sendInputEvent({type:'mouseUp',x:rect.x+Math.round(rect.width*.75),y:rect.y,button:'left',clickCount:1});await sleep(120);
  check(await js("document.querySelector('#commits').textContent==='1'"),'Mouse slider release did not commit once');
  await js("document.querySelector('[role=slider]').focus()");await key('Home');
  check(await js("Number(document.querySelector('[role=slider]').getAttribute('aria-valuenow'))===0&&document.querySelector('#commits').textContent==='2'"),'Slider keyboard commit failed');
  await js("document.querySelector('[data-mv-component=choice]').click()");await sleep(100);await key('End');await key('Enter');
  check(await js("document.querySelector('#choice-value').textContent==='album'&&!document.querySelector('[data-mv-menu]')"),'Custom choice keyboard selection failed');
  await js("document.querySelector('[role=checkbox]').focus()");await key('Space');
  check(await js("document.querySelector('[role=checkbox]').getAttribute('aria-checked')==='true'"),'Custom checkbox keyboard toggle failed');
  await key('Space');check(await js("document.querySelector('[role=checkbox]').getAttribute('aria-checked')==='false'"),'Custom checkbox toggled twice or failed to clear');
  const feedbackRect=await js("(()=>{const r=document.querySelector('#feedback').getBoundingClientRect();return {x:Math.round(r.x+r.width/2),y:Math.round(r.y+r.height/2)}})()");
  win.webContents.sendInputEvent({type:'mouseMove',...feedbackRect});await sleep(200);
  check(await js("Number(getComputedStyle(document.querySelector('#feedback')).scale)>1"),'Desktop hover feedback absent');
  win.webContents.sendInputEvent({type:'mouseDown',...feedbackRect,button:'left',clickCount:1});await sleep(200);
  check(await js("Number(getComputedStyle(document.querySelector('#feedback')).scale)<1"),'Press feedback absent');
  win.webContents.sendInputEvent({type:'mouseUp',...feedbackRect,button:'left',clickCount:1});await sleep(200);
  const beforeBusy=await js("document.querySelector('#commits').textContent");
  await js("document.querySelector('#busy-feedback').click()");
  check(await js("document.querySelector('#busy-feedback').disabled&&document.querySelector('#busy-feedback').getAttribute('aria-busy')==='true'"),'Busy action enabled');
  check(await js("document.querySelector('#commits').textContent")===beforeBusy,'Busy action submitted');
  await js("document.documentElement.classList.add('reduce-motion')");await sleep(30);
  check(await js("getComputedStyle(document.querySelector('#feedback')).scale==='1'&&getComputedStyle(document.querySelector('#feedback')).transitionDuration==='0s'"),'Reduced-motion feedback still animates');
  await js("document.documentElement.classList.remove('reduce-motion')");
  process.stdout.write('PASS own ActionButton hover/press, busy suppression and reduced motion\n');
  const image=await win.webContents.capturePage();const output=path.resolve(__dirname,'../.build/Shared/Core/desktop-components.png');fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,image.toPNG());
  process.stdout.write('PASS Electron menu edge placement, disabled skipping, wrap, Escape restore, Enter action; mouse slider hold/release and keyboard commit; custom choice and checkbox keyboard selection\n');clearTimeout(timeout);win.destroy();app.exit(0);
 }catch(error){process.stderr.write(error.stack+'\n');clearTimeout(timeout);win?.destroy();app.exit(1);}
});
