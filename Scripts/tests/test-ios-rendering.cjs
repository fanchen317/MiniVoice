const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false}});
 const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5198/tests/wall-mobile.html?host=ios');await pause(1000);
 await js("window.captures=0;window.captureStyleFixture=()=>{captures++;throw Error('Snapshot should not run')};document.querySelector('[aria-label=打开侧边栏]').click()");await pause(400);
 for(const style of ['simple','library','wall']){
  await js("document.querySelector('.mv-brand-logo').click()");await pause(650);
  assert.equal(await js("document.querySelector('main').dataset.style"),style);
  assert.equal(await js("!!document.querySelector('.mv-style-fragment-sweep')"),false);
  assert.equal(await js("getComputedStyle(document.querySelector('main')).opacity"),'1');
 }
 assert.equal(await js('captures'),0);
 // Latest intent, rotation and reduced motion must leave no faded/inert surface.
 await js("document.querySelector('.mv-brand-logo').click();document.querySelector('.mv-brand-logo').click()");win.setSize(956,440);await pause(900);
 assert.equal(await js("document.querySelector('main').dataset.style"),'library');
 assert.equal(await js("getComputedStyle(document.querySelector('main')).opacity"),'1');
 await js("document.documentElement.classList.add('reduce-motion');document.querySelector('.mv-brand-logo').click()");await pause(100);
 assert.equal(await js("document.querySelector('main').dataset.style"),'wall');
 await js("document.documentElement.classList.remove('reduce-motion');document.querySelector('[aria-label=关闭侧边栏]').click()");await pause(500);
 await js("window.posterMutations=0;window.posterObserver=new MutationObserver(r=>posterMutations+=r.length);posterObserver.observe(document.querySelector('.mv-wall-plane'),{subtree:true,attributes:true,attributeFilter:['style']})");await pause(1100);
 assert.equal(await js('posterMutations'),0,'Playback polling rewrote poster geometry');
 // Coverage must hold before the 140px rebase, then across repeated rebases.
 for(let i=0;i<18;i++){
  await js(`document.querySelector('.mv-cover-wall').dispatchEvent(new WheelEvent('wheel',{deltaX:${i<9?120:-120},deltaY:40,bubbles:true,cancelable:true}))`);await pause(40);
  const missing=await js("(async()=>{const {createScene,visibleTiles}=await import('/src/wallGeometry.js');const plane=document.querySelector('.mv-wall-plane'),camera=JSON.parse(plane.dataset.camera),expected=visibleTiles(createScene(1037),camera,{width:innerWidth,height:innerHeight},0),mounted=new Set([...plane.children].map(n=>n.dataset.wallCell));return expected.filter(cell=>!mounted.has(cell.id)).length})()");
  assert.equal(missing,0,'Visible wall cell missing before rebase');
 }
 await pause(600);assert.equal(await js("document.querySelector('.mv-wall-plane').dataset.compositedPan"),'true');
 console.log('PASS live style transitions, latest intent, resize, reduced motion, zero polling poster writes and fast-pan coverage');win.destroy();app.exit(0);
 }catch(e){console.error(e);win?.destroy();app.exit(1);}});
