// Current projected iOS fixture: raster/geometry evidence, not WKWebView GPU acceptance.
const {app,BrowserWindow,nativeImage}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const dpr=Number(process.env.MINIVOICE_TEST_DPR||1),base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5301';
const output=path.resolve('.build/reports/ui/ios-wall-edges/dpr-'+dpr),results=[];
let phase='starting';const deadline=setTimeout(()=>{console.error('iOS edge test timed out at '+phase);app.exit(1);},150000);
fs.mkdirSync(output,{recursive:true});fs.mkdirSync('.build/work',{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/ios-wall-edge-profile-')));
app.commandLine.appendSwitch('force-device-scale-factor',String(dpr));
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{let win,loaded=false;try{
 win=new BrowserWindow({show:false,useContentSize:true,width:390,height:844,webPreferences:{backgroundThrottling:false}});
 const js=async source=>{try{return await win.webContents.executeJavaScript(source,true);}catch(error){throw Error('Renderer script failed: '+source,{cause:error});}};
 const until=async(source,label)=>{for(let i=0;i<80;i++){if(await js(source))return;await wait(50);}throw Error(label);};
 async function freeze(){
  await js(`edgeClock.hold=true;edgePaused=document.getAnimations().filter(animation=>animation.playState==='running');edgePaused.forEach(animation=>animation.pause());true`);
  await js(`new Promise(resolve=>edgeClock.native(()=>edgeClock.native(resolve)))`);
 }
 async function resume(){await js('edgePaused.forEach(animation=>animation.play());edgeClock.release();true');}
 async function setupClock(){await js(`(()=>{
  const native=requestAnimationFrame.bind(window),cancel=cancelAnimationFrame.bind(window),tasks=new Map();let next=1000000000;
  const clock={native,hold:false,release(){this.hold=false;for(const [id,task]of tasks)if(task.held){task.held=false;task.native=native(time=>run(id,time));}}};
  function run(id,time){const task=tasks.get(id);if(!task)return;if(clock.hold){task.held=true;return;}tasks.delete(id);task.callback(time);}
  window.requestAnimationFrame=callback=>{const id=++next,task={callback,held:false};tasks.set(id,task);task.native=native(time=>run(id,time));return id;};
  window.cancelAnimationFrame=id=>{const task=tasks.get(id);if(task){cancel(task.native);tasks.delete(id);}else cancel(id);};window.edgeClock=clock;window.edgePaused=[];
 })()`);}
 async function load(width,height,color){
  phase=`load ${width}x${height} ${color}`;console.log('CHECK DPR '+dpr+' '+phase);
  if(loaded)await js("localStorage.removeItem('wall-fixture-v2');sessionStorage.removeItem('wall-fixture-started');true");
  win.setContentSize(width,height);
  await win.loadURL(base+'/tests/wall-mobile.html?host=ios');
  loaded=true;
  console.log('CHECK DPR '+dpr+' loaded');
  if(!win.webContents.debugger.isAttached())win.webContents.debugger.attach('1.3');
  phase='emulation';
  await win.webContents.debugger.sendCommand('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:dpr,mobile:false});
  console.log('CHECK DPR '+dpr+' emulation ready');
  assert.equal(await js('devicePixelRatio'),dpr,'Fixture did not use the requested DPR');
  await until("document.querySelector('.mv-wall-card')&&wallFixture.state.songs.length>1000",'Missing projected wall');
  await js(`window.edgeCoverURL='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><path fill="${color}" d="M0 0h512v512H0z"/></svg>');wallFixture.state.songs=wallFixture.state.songs.map(song=>({...song,artwork:edgeCoverURL}));true`);
  await until(`(()=>{const images=[...document.querySelectorAll('.mv-wall-card img')];return images.length>4&&images.every(image=>image.complete&&image.naturalWidth&&image.getAttribute('src')===edgeCoverURL);})()`,'Synthetic covers not decoded');
  await wait(150);assert.equal(await js("document.querySelector('.mv-cover-wall').dataset.wallRenderer"),'projected-single-surface');
  await setupClock();
 }
 async function pick(excluded=[]){return js(`(()=>{
  const nodes=[...document.querySelectorAll('.mv-wall-card:not(.is-focus-underlay)')].filter(node=>!${JSON.stringify(excluded)}.includes(node.dataset.wallId));
  const node=nodes.find(node=>{const r=node.getBoundingClientRect();return r.width>40&&r.height>40&&r.right>80&&r.left<innerWidth-80&&r.bottom>130&&r.top<innerHeight-130;})||nodes[0];
  if(!node)throw Error('No poster to select');node.click();return node.dataset.wallId;
 })()`);}
 async function overscanAB(label){
  const measure=()=>js(`(()=>{const node=document.querySelector('.mv-wall-card>.mv-wall-press-surface'),image=node.querySelector('img'),a=node.getBoundingClientRect(),b=image.getBoundingClientRect();return {position:getComputedStyle(image).position,left:a.left-b.left,top:a.top-b.top,right:b.right-a.right,bottom:b.bottom-a.bottom};})()`);
  await js(`(()=>{const style=document.createElement('style');style.id='edge-baseline';style.textContent='[data-host=iOS] .mv-wall-card>.mv-wall-press-surface>img{position:static!important}';document.head.appendChild(style);})()`);
  const baseline=await measure();assert.equal(baseline.position,'static');assert.ok(Math.abs(baseline.left)<.02&&Math.abs(baseline.top)<.02&&baseline.right>1.9&&baseline.bottom>1.9,'Legacy asymmetry was not reproduced');
  await raster(label+'-legacy-static');
  await js("document.getElementById('edge-baseline').remove()");const corrected=await measure();
  assert.equal(corrected.position,'absolute');for(const edge of ['left','top','right','bottom'])assert.ok(Math.abs(corrected[edge]-1)<.03,'Symmetric image bleed failed: '+JSON.stringify(corrected));
  results.push({label,baseline,corrected});
 }
 async function raster(label,{negative=false}={}){
  phase=label+' freeze';console.log('CHECK DPR '+dpr+' '+label);
  await freeze();
  const geometry=await js(`(()=>{
   const rect=node=>{const r=node.getBoundingClientRect();return {left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,height:r.height};};
   const visible=node=>{const s=getComputedStyle(node);return s.visibility!=='hidden'&&s.display!=='none'&&Number(s.opacity)!==0;};
   const occluders=[...document.querySelectorAll('.mv-wall-focused,.mv-wall-focus-outline,.mv-wall-current-outline,.mv-toolbar>*:not([hidden]),.mv-wall-dock,[data-wall-control=settings],.mv-drawer-shade>.mv-drawer,[data-surface-exit=drawer] .mv-drawer')].filter(visible).map(rect);
   const cards=[...document.querySelectorAll('.mv-wall-card:not(.active):not(.is-focus-underlay):not(.is-touch-pressed)')].filter(visible).map(node=>({id:node.dataset.wallCell,...rect(node.querySelector('.mv-wall-press-surface'))}));
   return {width:innerWidth,height:innerHeight,cards,occluders};
  })()`);
  // Native macOS capturePage can retain the host display's 2x backing even
  // when the page is emulating another DPR. CDP captures the emulated raster.
  phase=label+' capture';
  const capture=await win.webContents.debugger.sendCommand('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
  const image=nativeImage.createFromBuffer(Buffer.from(capture.data,'base64')),size=image.getSize(),bits=image.toBitmap(),ratio=size.width/geometry.width;
  assert.ok(Math.abs(ratio-dpr)<.02,'Screenshot did not preserve physical pixels');
  const rgb=(x,y)=>{const px=Math.floor(x*ratio),py=Math.floor(y*ratio);if(px<0||py<0||px>=size.width||py>=size.height)return null;const i=(py*size.width+px)*4;return [bits[i+2],bits[i+1],bits[i]];};
  const occluded=(x,y)=>geometry.occluders.some(r=>x>=r.left-3&&x<=r.right+3&&y>=r.top-3&&y<=r.bottom+3);
  const failures=[];let samples=0;const sides=new Set();
  for(const card of geometry.cards){
   if(card.width<25||card.height<25)continue;
   for(const side of ['left','right','top','bottom'])for(const fraction of [.2,.35,.5,.65,.8]){
    const horizontal=side==='top'||side==='bottom',edge=card[side];
    const other=horizontal?card.left+card.width*fraction:card.top+card.height*fraction;
    const insideEdge=edge+((side==='left'||side==='top')?4:-4);
    const inside=horizontal?{x:other,y:insideEdge}:{x:insideEdge,y:other};
    if(occluded(inside.x,inside.y))continue;const reference=rgb(inside.x,inside.y);if(!reference)continue;
    for(const offset of [-.5,.5,1.5]){
     const sampleEdge=(Math.floor(edge*ratio)+offset)/ratio,sample=horizontal?{x:other,y:sampleEdge}:{x:sampleEdge,y:other};
     if(occluded(sample.x,sample.y))continue;const color=rgb(sample.x,sample.y);if(!color)continue;
     // White/yellow art plus black shading cannot grow brighter at its clip.
     // A real mint playing contour is excluded above, as are focus/press whites.
     const neutral=Math.max(...color)-Math.min(...color)<14;
     const brighter=neutral?Math.min(...color.map((value,i)=>value-reference[i])):Math.min(color[0]-reference[0],color[1]-reference[1]);
     samples++;sides.add(side);if(brighter>32)failures.push({id:card.id,side,sample,color,inside,reference,brighter});
    }
   }
  }
  const result={label,samples,sides:[...sides],failures:failures.slice(0,12)};results.push(result);
  fs.writeFileSync(path.join(output,label+'.png'),image.toPNG());await resume();
  assert.ok(samples>=15&&sides.size>=3,'Insufficient unoccluded physical edge samples: '+JSON.stringify(result));
  if(negative)assert.ok(failures.length>0,'Pixel probe did not detect a deliberately exposed unshaded edge');
  else assert.equal(failures.length,0,'Unshaded edge pixels: '+JSON.stringify(result));
 }
 async function touchCancellation(){
  await js(`(()=>{const node=[...document.querySelectorAll('.mv-wall-card:not(.active):not(.is-focus-underlay)')].find(n=>{const r=n.getBoundingClientRect();return r.right>70&&r.left<innerWidth-70&&r.bottom>100&&r.top<innerHeight-120;}),r=node.getBoundingClientRect();window.edgeTouchNode=node;window.edgeTouchPoint={x:r.left+r.width/2,y:r.top+r.height/2};const touch=new Touch({identifier:45,target:node,clientX:edgeTouchPoint.x,clientY:edgeTouchPoint.y});node.dispatchEvent(new TouchEvent('touchstart',{bubbles:true,cancelable:true,touches:[touch],changedTouches:[touch]}));})()`);await wait(55);
  assert.ok(await js("edgeTouchNode.classList.contains('is-touch-pressed')&&getComputedStyle(edgeTouchNode.querySelector('.mv-wall-press-outline')).opacity==='1'"),'Legal touch contour was removed');
  await js("edgeTouchNode.dispatchEvent(new TouchEvent('touchcancel',{bubbles:true,cancelable:true,touches:[],changedTouches:[]}))");await wait(140);
  assert.ok(await js("!edgeTouchNode.classList.contains('is-touch-pressed')&&getComputedStyle(edgeTouchNode.querySelector('.mv-wall-press-outline')).opacity==='0'"),'Touch cancellation left a white contour');
 }
 for(const [orientation,width,height]of [['portrait',390,844],['landscape',956,440]]){
  await load(width,height,'#ffffff');await overscanAB(orientation+'-overscan');
  // Deliberately shorten a shade in a disposable probe. This proves that the
  // pixel assertion detects a real exposed stripe, not just matching CSS.
  await js(`(()=>{const style=document.createElement('style');style.id='edge-negative';style.textContent='.mv-wall-card>.mv-wall-press-surface::before{inset:2px!important}.mv-wall-caption{background:none!important}';document.head.appendChild(style);})()`);
  await raster(orientation+'-probe-negative',{negative:true});await js("document.getElementById('edge-negative').remove()");
  await raster(orientation+'-rest');await touchCancellation();
  const first=await pick(['0']);await wait(90);await raster(orientation+'-focus-mid');
  const second=await pick(['0',first]);await wait(85);await raster(orientation+'-switch-mid');
  const last=await pick(['0',second]);await wait(720);
  assert.equal(await js("document.querySelector('.mv-wall-focused').dataset.wallId"),last,'A canceled focus animation overwrote the latest selection');
  assert.ok(await js("(()=>{const scope=document.querySelector('.mv-wall-focused'),outline=scope.querySelector('.mv-wall-focus-outline'),a=scope.querySelector('.mv-wall-press-surface').getBoundingClientRect(),b=outline.getBoundingClientRect(),s=getComputedStyle(outline);return s.display!=='none'&&s.borderTopWidth==='1.5px'&&Math.abs(a.width-b.width)<.1&&Math.abs(a.height-b.height)<.1&&Math.abs(a.width-a.height)<1;})()"),'Preview white contour/final square geometry was lost');
  await js(`wallFixture.state.current=${JSON.stringify(last)};true`);
  await until("!!document.querySelector('.mv-wall-focused.is-current .mv-wall-current-outline')",'Host current-song update did not reach the selected card');
  assert.ok(await js("(()=>{const n=document.querySelector('.mv-wall-focused .mv-wall-current-outline'),s=getComputedStyle(n);return s.display!=='none'&&s.borderTopWidth==='3px'&&s.borderTopColor==='rgb(50, 216, 181)';})()"),'Current-song mint contour was removed');
  await js("window.edgeCamera=document.querySelector('.mv-wall-plane').dataset.camera;document.querySelector('[aria-label=打开侧边栏]').click()");await wait(105);await raster(orientation+'-drawer-mid');
  await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(80);await raster(orientation+'-drawer-reverse');
  await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(150);await raster(orientation+'-drawer-reopen');await wait(350);
  assert.equal(await js("document.querySelector('.mv-wall-plane').dataset.camera"),await js('edgeCamera'),'Drawer depth changed the wall camera');
  assert.ok(await js("document.querySelector('.mv-scene').inert"),'Open drawer did not block background input');
  await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(400);
  assert.ok(await js("!document.querySelector('.mv-scene').inert&&getComputedStyle(document.querySelector('.mv-scene')).transform==='none'"),'Drawer did not reach real final layout');
  await js("document.documentElement.classList.add('reduce-motion');document.querySelector('[aria-label=打开侧边栏]').click()");await wait(80);await raster(orientation+'-reduced-drawer');
  await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(80);assert.ok(await js("getComputedStyle(document.querySelector('.mv-scene')).transform==='none'"),'Reduced-motion return did not finish');
  await load(width,height,'#ffff00');await pick(['0']);await wait(110);await raster(orientation+'-yellow-focus-mid');
 }
 // The ordinary image positioning change is intentionally scoped to iOS.
 await win.loadURL(base+'/tests/wall-mobile.html');await until("!!document.querySelector('.mv-wall-card img')",'Missing Android fixture');
 assert.equal(await js("getComputedStyle(document.querySelector('.mv-wall-card img')).position"),'static','iOS fix changed Android card layout');
 fs.writeFileSync(path.join(output,'report.json'),JSON.stringify({dpr,results},null,2));
 console.log('PASS iOS projected four-edge overscan A/B, guarded physical edge pixels, legal contours, focus/drawer interruption and final layout; DPR '+dpr);clearTimeout(deadline);win.destroy();app.exit(0);
}catch(error){console.error(error);fs.writeFileSync(path.join(output,'report.json'),JSON.stringify({dpr,error:String(error),results},null,2));if(win)fs.writeFileSync(path.join(output,'failure.png'),(await win.webContents.capturePage()).toPNG());clearTimeout(deadline);win?.destroy();app.exit(1);}});
