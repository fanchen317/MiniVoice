// Chromium raster/interaction regression; WKWebView compositing still needs device acceptance.
const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const output=path.resolve('.build/reports/ui/drawer-landscape');
fs.mkdirSync(output,{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/drawer-edge-profile-')));
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5299';
const results=[];
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:956,height:440,useContentSize:true,webPreferences:{backgroundThrottling:false}});
 const js=async source=>{try{return await win.webContents.executeJavaScript(source,true);}catch(error){throw Error('Renderer script failed: '+source,{cause:error});}};
 const until=async(source,label)=>{for(let i=0;i<70;i++){if(await js(source))return;await wait(80);}throw Error(label);};
 const open=async()=>{await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(450);};
 const close=async()=>{await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(450);};
 async function raster(label,points){
  const image=await win.webContents.capturePage(),size=await js('({width:innerWidth,height:innerHeight})');
  fs.writeFileSync(path.join(output,label+'.png'),image.toPNG());
  const pixels=image.resize(size).toBitmap();
  const color=point=>{const index=(Math.round(point.y)*size.width+Math.round(point.x))*4;return [...pixels.subarray(index,index+3)];};
  const a=color(points.inside),b=color(points.outside),difference=Math.max(...a.map((v,i)=>Math.abs(v-b[i])));
  results.push({label,points,inside:a,outside:b,difference});
  assert.ok(difference<=3,`${label}: live artwork shade changes at drawer edge: ${JSON.stringify({a,b,difference,points})}`);
 }
 async function boundary(kind){return js(`(()=>{const scene=document.querySelector('.mv-scene').getBoundingClientRect(),edge=scene.right;
  const candidates=[...document.querySelectorAll(${JSON.stringify(kind==='poster'?'.mv-wall-card:not(.active)':'.mv-wall-focused')})];
  for(const node of candidates){const r=node.getBoundingClientRect(),caption=node.querySelector('.mv-wall-caption')?.getBoundingClientRect(),y=${kind==='poster'?'caption?.bottom-5':'r.top+r.height*.35'};
   if(r.left<edge-8&&r.right>innerWidth&&y>scene.top+32&&y<scene.bottom-32)return {inside:{x:edge-4,y},outside:{x:Math.min(innerWidth-2,edge+4),y}};
  }return null;})()`);}
 await win.loadURL(base+'/tests/wall-mobile.html?host=ios');
 await until("document.querySelector('main')?.dataset.ready==='true'&&document.querySelectorAll('.mv-wall-card').length>0",'iOS wall did not load');
 await js(`(()=>{const artwork='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><path fill="#c8c8c8" d="M0 0h512v512H0z"/></svg>');wallFixture.state.songs=wallFixture.state.songs.map(song=>({...song,artwork,artworkWall:artwork,artworkCard:artwork,artworkDetail:artwork}));
 document.querySelector('main').style.cssText+=';--mv-safe-left:59px;--mv-safe-right:0px;--mv-safe-top:0px;--mv-safe-bottom:21px';
 const style=document.createElement('style');style.textContent='.mv-wall-caption strong,.mv-wall-caption small{color:transparent!important;text-shadow:none!important}.mv-wall-focus-content{visibility:hidden!important}';document.head.append(style);})()`);
 await wait(750);
 const camera=await js("document.querySelector('.mv-wall-plane').dataset.camera");
 await open();
 let points=await boundary('poster');assert.ok(points,'No ordinary cover crosses the recessed right boundary');
 await raster('ios-dark-caption',points);
 assert.equal(await js("document.querySelectorAll('.mv-wall-drawer-backdrop').length"),0,'iOS still has a differently shaded cover copy');
 assert.ok(await js("(()=>{const scene=document.querySelector('.mv-scene'),body=scene.querySelector('.mv-body'),wall=body.querySelector('.mv-cover-wall'),root=document.querySelector('main'),material=document.querySelector('.mv-drawer-material');return [scene,body,wall].every(node=>getComputedStyle(node).overflow==='visible')&&['hidden','clip'].includes(getComputedStyle(root).overflow)&&scene.inert&&material.dataset.sampled==='true'&&getComputedStyle(material.querySelector('.mv-drawer-sample')).filter.includes('blur(24px)')})()"),'Live extension lost viewport clipping, input blocking or drawer glass');
 assert.equal(await js("document.querySelector('.mv-wall-plane').dataset.camera"),camera,'Opening drawer changed saved camera');
 // Opening reversal and the return path must use the same live surface, too.
 await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(90);
 await raster('ios-closing-caption',await boundary('poster'));
 await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(80);
 await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(400);
 assert.equal(await js("document.querySelector('.mv-wall-plane').dataset.camera"),camera);
 assert.ok(await js("getComputedStyle(document.querySelector('.mv-scene')).transform==='none'&&!document.querySelector('.mv-scene').inert"),'Interrupted drawer did not return to real layout');
 // Shift a real focused card across the same boundary. Its gradient differs from ordinary covers.
 await js("document.querySelector('.mv-wall-card[data-wall-id=\"0\"]').click()");await wait(650);
 await js("(()=>{const r=document.querySelector('.mv-wall-focused').getBoundingClientRect();document.querySelector('.mv-cover-wall').dispatchEvent(new WheelEvent('wheel',{deltaX:r.right-innerWidth-70,deltaY:0,bubbles:true,cancelable:true}))})()");await wait(150);
 await open();points=await boundary('focus');assert.ok(points,'Focused cover does not cross the edge');await raster('ios-dark-focus',points);
 assert.ok(await js("(()=>{const surface=document.querySelector('.mv-wall-focused>.mv-wall-press-surface');return getComputedStyle(surface).maskImage!=='none'&&getComputedStyle(document.querySelector('.mv-wall-focused')).overflow!=='visible'})()"),'Live extension removed the focused card local clip');
 // Both themes and the opposite landscape safe area retain the same physical surface.
 await js("document.querySelector('.mv-drawer [aria-label=设置]').click()");await wait(300);
 await js("[...document.querySelectorAll('.mv-mobile-settings button')].find(node=>node.textContent.startsWith('浅色模式')).click()");await wait(220);
 await js("document.querySelector('[aria-label=关闭弹窗]').click();document.querySelector('main').style.cssText+=';--mv-safe-left:0px;--mv-safe-right:59px'");await wait(350);await open();
 assert.equal(await js("document.querySelector('main').dataset.theme"),'light');await raster('ios-light-focus',await boundary('focus'));
 await close();await js("document.documentElement.classList.add('reduce-motion')");await open();
 assert.ok(await js("document.querySelector('.mv-scene').getAnimations().length===0"),'Reduced-motion drawer animated');await raster('ios-reduced-focus',await boundary('focus'));
 // An empty wall must not reveal the workspace's different theme background at its edges.
 await close();await js("wallFixture.state.songs=[]");await wait(650);await open();
 points=await js("(()=>{const r=document.querySelector('.mv-scene').getBoundingClientRect();return {inside:{x:r.right-4,y:150},outside:{x:Math.min(innerWidth-2,r.right+4),y:150}}})()");await raster('ios-empty',points);
 await close();assert.ok(await js("document.querySelector('main').scrollLeft===0&&document.querySelector('.mv-cover-wall').scrollLeft===0"),'Canvas became scrollable');
 win.destroy();win=null;
 // Android keeps its existing extension; desktop stays its own input family.
 for(const fixture of ['wall-mobile.html?host=android','wall-desktop.html']){
  win=new BrowserWindow({show:false,width:956,height:440,useContentSize:true,webPreferences:{backgroundThrottling:false}});
  await win.loadURL(base+'/tests/'+fixture);await wait(900);
  if(fixture.includes('mobile')){await open();assert.equal(await js("document.querySelectorAll('.mv-wall-drawer-backdrop').length"),1);assert.equal(await js("getComputedStyle(document.querySelector('.mv-cover-wall')).overflow"),'clip');}
  else assert.equal(await js("document.querySelector('main')?.dataset.presentation||document.querySelector('[data-presentation]')?.dataset.presentation"),'desktop');
  win.destroy();win=null;
 }
 fs.writeFileSync(path.join(output,'work.json'),JSON.stringify(results,null,2));
 console.log('PASS iOS landscape caption/focus/empty-wall raster continuity, themes/safe areas, interruption/return, reduced motion, local masks and Android/desktop isolation');app.exit(0);
}catch(error){fs.writeFileSync(path.join(output,'work-failed.json'),JSON.stringify({results,error:error.message},null,2));console.error(error);win?.destroy();app.exit(1);}});
