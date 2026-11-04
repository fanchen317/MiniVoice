const {app,BrowserWindow,protocol}=require('electron');
const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
app.whenReady().then(async()=>{let win;try{
 protocol.handle('minivoice-art',()=>new Response('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><rect width="512" height="512" fill="#345e4b"/></svg>',{headers:{'Content-Type':'image/svg+xml','Access-Control-Allow-Origin':'*'}}));
 win=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false,partition:'refinements-'+Date.now()}});const errors=[];win.webContents.on('console-message',(_e,level,message)=>{if(level>=3&&/Uncaught|TypeError|ReferenceError|Maximum update/.test(message))errors.push(message);});
 win.webContents.session.protocol.handle('minivoice-art',()=>new Response('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><rect width="512" height="512" fill="#345e4b"/></svg>',{headers:{'Content-Type':'image/svg+xml','Access-Control-Allow-Origin':'*'}}));
 const js=source=>win.webContents.executeJavaScript(source,true),click=async label=>{assert.ok(await js(`(()=>{const n=[...document.querySelectorAll('button')].find(n=>n.getAttribute('aria-label')===${JSON.stringify(label)}||n.textContent===${JSON.stringify(label)});if(!n)return false;n.click();return true;})()`),label);await wait(350);};
 const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5194';
 for(const host of ['ios','android']){
  if(win.webContents.getURL().startsWith(base))await js('localStorage.clear();sessionStorage.clear()');
  await win.loadURL(base+'/tests/wall-mobile.html?host='+host);await wait(900);await js('document.querySelector(\'.mv-wall-card[data-wall-id="0"]\').click()');await wait(700);
  await click('展开播放器');await wait(400);await click('切换高斯模糊插图');assert.equal(await js("document.querySelector('.mv-wall-focused').dataset.artworkMode"),'blurred');await wait(450);assert.ok(await js("(()=>{const n=document.querySelector('.mv-wall-focused .mv-artwork-blur'),s=getComputedStyle(n);return n.naturalWidth>0&&+s.opacity>.99&&s.filter.includes('blur')&&document.querySelector('.artwork-mode-toggle svg').dataset.icon==='artworkSoft'})()"),'Mode must draw decoded blurred pixels and switch icon');await click('切换清晰插图');await wait(450);assert.ok(await js("+getComputedStyle(document.querySelector('.mv-wall-focused .mv-artwork-blur')).opacity===0&&document.querySelector('.artwork-mode-toggle svg').dataset.icon==='artworkSharp'"));
  await click('收起播放器');await wait(350);await click('收藏歌曲');
  assert.ok(await js("(()=>{const b=document.querySelector('.wp-controls [aria-label=取消收藏]'),s=getComputedStyle(b);return s.backgroundColor==='rgba(0, 0, 0, 0)'&&s.boxShadow==='none'&&s.outlineStyle==='none'&&b.querySelector('[data-icon=heart]').getAttribute('fill')==='currentColor'})()"),'Saved heart must stay flat and filled');
  const heart=await js("(()=>{const r=document.querySelector('.wp-controls [aria-label=取消收藏]').getBoundingClientRect();return {x:Math.round(r.x+r.width/2),y:Math.round(r.y+r.height/2)}})()");win.webContents.sendInputEvent({type:'mouseDown',button:'left',clickCount:1,...heart});await wait(30);
  assert.ok(await js("getComputedStyle(document.querySelector('.wp-controls [aria-label=取消收藏]')).backgroundColor!=='rgba(0, 0, 0, 0)'"),'Pressed heart needs visible feedback');win.webContents.sendInputEvent({type:'mouseUp',button:'left',clickCount:1,...heart});await wait(450);
  await click('打开侧边栏');await click('切换到简易样式');await wait(800);await click('关闭侧边栏');await click('打开侧边栏');await click('选择歌曲');
  await js("document.querySelector('.mv-sidebar-catalog .mv-song').click()");await wait(200);await click('批量操作');
  assert.ok(await js("(()=>{const m=document.querySelector('.mv-modal-shade'),d=document.querySelector('.mv-drawer-shade');return +getComputedStyle(m).zIndex>+getComputedStyle(d).zIndex})()"));
  assert.ok(await js("!document.querySelector('.mv-collection-content>.mv-settings-note')"),'Song menu repeats song name');await click('多选');await js("document.querySelector('.mv-sidebar-catalog .mv-song').dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}));true");assert.ok(await js("!document.querySelector('.mv-modal-shade')"),'Selection mode opens song menu');assert.ok(await js("document.querySelector('.mv-sidebar-catalog .mv-selection-bar').textContent.includes('已选择 1 首')"));
  await click('关闭侧边栏');await click('打开侧边栏');await click('设置');assert.ok(await js("!document.querySelector('.mv-mobile-settings').textContent.match(/启用扫描通知|返回播放器/)"));
  console.log('PASS '+host+' expanded artwork mode, simple selection, menu above drawer and settings cleanup (Electron)');
 }
 win.setContentSize(1040,780);await win.loadURL(base+'/tests/wall-desktop.html');await wait(900);await click('展开播放器');await wait(500);await click('切换高斯模糊插图');await wait(450);assert.ok(await js("(()=>{const p=document.querySelector('.wall-poster.focused'),n=p.querySelector('.mv-artwork-blur'),s=getComputedStyle(n);return n.naturalWidth>0&&+s.opacity>.99&&getComputedStyle(p,'::after').display==='none'})()"),'Mac blur must paint decoded pixels without contour');await click('收起播放器');await wait(500);await js("window.desktopWallFixture.open('editor')");await wait(500);
 for(const tab of ['歌曲信息','歌词与翻译','插图']){await js(`Array.from(document.querySelectorAll('[data-own-surface=editor] nav button')).find(n=>n.textContent===${JSON.stringify(tab)}).click()`);await wait(200);assert.ok(await js("!document.querySelector('[data-own-surface=editor]').textContent.match(/编辑名称、歌手和专辑|导入或编辑歌词，在预览/)"));}
 await js("Array.from(document.querySelectorAll('[data-own-surface=editor] nav button')).find(n=>n.textContent==='歌曲信息').click()");await wait(200);
 await click('添加歌手');assert.equal(await js("document.querySelectorAll('[aria-label^=\"歌手名称\"]').length"),2);await click('源文件名智能识别');assert.ok(await js("document.querySelector('[role=alert]')?.textContent.includes('分隔符')"));
 const target=path.resolve(__dirname,'../../.build/reports/ui/editor-refinements.png');fs.writeFileSync(target,(await win.webContents.capturePage()).toPNG());
 await click('保存修改');assert.ok(await js("window.desktopWallFixture.calls.some(c=>c.name==='saveMetadata'&&c.payload.title&&c.payload.destination)"));
 assert.deepEqual(errors,[]);console.log('PASS Mac editor three tabs, removed descriptions, artist draft, filename error and save command');
 win.destroy();app.exit(0);
 }catch(error){console.error(error);if(win)console.error(await win.webContents.executeJavaScript("({url:location.href,body:document.body.innerText.slice(0,500)})").catch(()=>null));win?.destroy();app.exit(1);}});
