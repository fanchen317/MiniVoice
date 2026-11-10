// Real Chromium page evidence; GPU, WebView and WKWebView need device acceptance.
const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5192';
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{let win;try{
 const results=[];
 for(const host of ['android','ios']){
  win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});
  const js=source=>win.webContents.executeJavaScript(source,true);
  await win.loadURL(base+'/tests/wall-mobile.html?host='+host);await wait(900);
  await js(`window.artworkRequests=[];window.NativeImage=Image;window.Image=class extends NativeImage{set src(value){artworkRequests.push({source:value,mounted:[...document.querySelectorAll('.mv-wall-card img')].some(node=>node.getAttribute('src')===value)});super.src=value;}get src(){return super.src;}};true`);
  const before=await js("JSON.parse(document.querySelector('.mv-wall-plane').dataset.camera)");
  for(let i=0;i<12;i++){await js("document.querySelector('.mv-cover-wall').dispatchEvent(new WheelEvent('wheel',{deltaX:90,deltaY:25,bubbles:true,cancelable:true}))");await wait(40);}
  await wait(500);
  const warm=await js("({camera:JSON.parse(document.querySelector('.mv-wall-plane').dataset.camera),requests:artworkRequests.length,ahead:artworkRequests.filter(request=>!request.mounted).length,cards:document.querySelectorAll('.mv-wall-card').length,plane:getComputedStyle(document.querySelector('.mv-wall-plane')).transform})");
  assert.ok(warm.camera.x<before.x-1000&&warm.camera.y<before.y-250,'Prefetch blocked wall movement');
  assert.ok(warm.requests>0&&warm.ahead>0,'No offscreen covers decoded ahead of mounting');
  assert.ok(warm.cards<200&&warm.plane==='none','Speculation mounted the library or promoted a giant plane');
  // The current pointer/camera is authoritative if motion preferences change
  // during a fling; an old animation must not keep writing positions afterward.
  await js(`(()=>{const wall=document.querySelector('.mv-cover-wall');for(const [type,x] of [['pointerdown',190],['pointermove',125],['pointerup',100]])wall.dispatchEvent(new PointerEvent(type,{pointerId:77,pointerType:'touch',button:0,clientX:x,clientY:410,bubbles:true}));})();true`);
  await wait(50);await js("document.documentElement.classList.add('reduce-motion')");await wait(60);
  const stopped=await js("JSON.parse(document.querySelector('.mv-wall-plane').dataset.camera)");await wait(180);
  assert.deepEqual(await js("JSON.parse(document.querySelector('.mv-wall-plane').dataset.camera)"),stopped,'Reduced motion did not stop the current fling');
  for(const theme of ['light','dark']){
   await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(250);
   await js("document.querySelector('.mv-drawer [aria-label=设置]').click()");await wait(250);
   await js(`Array.from(document.querySelectorAll('.mv-mobile-settings button')).find(node=>node.textContent.startsWith(${JSON.stringify(theme==='light'?'浅色模式':'深色模式')})).click();true`);await wait(250);
   await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(250);
   assert.equal(await js("document.querySelector('main').dataset.theme"),theme);
   assert.ok(await js("[...document.querySelectorAll('.mv-wall-card img')].some(image=>image.complete&&image.naturalWidth>0)"));
  }
  // A new mount must consume a new locate token; ordinary returns must not replay it.
  await js("wallFixture.state.current='903';true");await wait(500);
  await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(200);
  for(let i=0;i<3&&await js("document.querySelector('main').dataset.style!=='library'");i++){await js("document.querySelector('.mv-brand-logo').click()");await wait(300);}
  await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(300);
  assert.ok(await js("document.querySelector('.mv-song-list').scrollTop>1000"),'A new mounted list ignored its explicit locate request');
  await js("document.querySelector('.mv-song-list').scrollTop=413;true");await wait(450);
  for(const section of ['歌手','音乐库']){
   await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(150);
   await js(`Array.from(document.querySelectorAll('.mv-drawer nav button')).find(node=>node.textContent===${JSON.stringify(section)}).click();true`);await wait(450);
  }
  assert.ok(await js("Math.abs(document.querySelector('.mv-song-list').scrollTop-413)<2"),'Consumed locate intent reset the restored library anchor');
  await js("wallFixture.state.current='0';true");await wait(500);
  await js("document.querySelector('[aria-label=定位正在播放的歌曲]').click()");await wait(300);
  assert.equal(await js("document.querySelector('.mv-song-list').scrollTop"),0,'A new locate request was ignored');
  results.push({host,...warm});win.destroy();win=null;
 }
 fs.mkdirSync('.build/reports/ui/wall-cache-performance',{recursive:true});fs.writeFileSync('.build/reports/ui/wall-cache-performance/work.json',JSON.stringify(results,null,2));
 console.log('PASS Android/iOS 1037-song predictive artwork, bounded mounted scene, uninterrupted pan, reduced-motion fling cancellation light/dark themes and consumed locate/return anchors');app.exit(0);
}catch(error){console.error(error);win?.destroy();app.exit(1);}});
