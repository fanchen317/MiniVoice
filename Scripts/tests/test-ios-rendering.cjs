const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false}});
 const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5198/tests/wall-mobile.html?host=ios');await pause(1000);
 // The web fixture retains the shared fragment renderer; UIKit is tested in WK.
 await js('window.styleShot='+JSON.stringify((await win.webContents.capturePage()).toDataURL()));
 await js("window.captureStyleFixture=async()=>styleShot;document.querySelector('[aria-label=打开侧边栏]').click()");await pause(400);
 for(const style of ['simple','library','wall']){
  await js("document.querySelector('.mv-brand-logo').click()");await pause(180);
  assert.equal(await js("!!document.querySelector('.mv-style-fragment-sweep')"),true,'Fragment animation was replaced');
  await pause(700);assert.equal(await js("document.querySelector('main').dataset.style"),style);
 }
 await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await pause(500);
 await js("window.posterMutations=0;window.posterObserver=new MutationObserver(r=>posterMutations+=r.length);posterObserver.observe(document.querySelector('.mv-wall-plane'),{subtree:true,attributes:true,attributeFilter:['style']})");await pause(1100);
 assert.equal(await js('posterMutations'),0,'Playback polling rewrote poster geometry');
 assert.equal(await js("getComputedStyle(document.querySelector('.mv-cover-wall')).overflowY"),'auto');
 win.webContents.debugger.attach('1.3');
 const touch=(type,touchPoints)=>win.webContents.debugger.sendCommand('Input.dispatchTouchEvent',{type,touchPoints});
 const initial=await js("document.querySelector('.mv-cover-wall').scrollTop");
 await touch('touchStart',[{x:210,y:600,id:1}]);
 for(let i=1;i<=18;i++){await touch('touchMove',[{x:210,y:600-i*15,id:1}]);await pause(12);}
 await touch('touchEnd',[]);await pause(600);
 assert.ok(await js(`document.querySelector('.mv-cover-wall').scrollTop>${initial}+200`),'Trusted touch did not drive native scrolling');
 await touch('touchStart',[{x:120,y:350,id:1},{x:280,y:350,id:2}]);
 for(let i=1;i<=5;i++){await touch('touchMove',[{x:120-i*5,y:350,id:1},{x:280+i*5,y:350,id:2}]);await pause(15);}
 await touch('touchEnd',[]);await pause(300);
 assert.ok(await js("Number(document.querySelector('.mv-cover-wall').dataset.wallScale)>1.1"),'Two-finger wall zoom failed');
 assert.equal(await js('visualViewport.scale'),1,'Pinch zoomed the document');
 // Cross multiple virtual boundaries in both directions, including recentering.
 for(let i=0;i<19;i++){
  await js(`document.querySelector('.mv-cover-wall').scrollLeft${i===18?'=40':'+='+(i<9?180:-180)}`);await pause(40);
  const missing=await js("(async()=>{const {createScene,visibleTiles}=await import('/src/wallGeometry.js');const plane=document.querySelector('.mv-wall-plane'),camera=JSON.parse(plane.dataset.camera),expected=visibleTiles(createScene(1037),camera,{width:innerWidth,height:innerHeight},0),mounted=new Set([...plane.children].map(n=>n.dataset.wallCell));return expected.filter(cell=>!mounted.has(cell.id)).length})()");
  assert.equal(missing,0,'Visible wall cell missing during native pan/recentering');
 }
 console.log('PASS original fragment effect, zero polling poster writes, trusted native touch scroll, two-finger wall zoom and recenter coverage');win.destroy();app.exit(0);
 }catch(e){console.error(e);win?.destroy();app.exit(1);}});
