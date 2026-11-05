const {app,BrowserWindow,protocol}=require('electron');const assert=require('node:assert/strict');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}}]);
app.whenReady().then(async()=>{let w;try{
 w=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false,partition:'wall-current-'+Date.now()}});const js=async s=>{try{return await w.webContents.executeJavaScript(s,true)}catch(e){console.error('FAILED JS',s);throw e}};w.webContents.on('console-message',(_e,level,message)=>{if(level>=3)console.error(message)});
 w.webContents.session.protocol.handle('minivoice-art',()=>new Response('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><rect width="512" height="512" fill="#216a48"/></svg>',{headers:{'Content-Type':'image/svg+xml','Access-Control-Allow-Origin':'*'}}));
 for(const host of ['ios','android']){
  if(w.webContents.getURL().startsWith('http'))await js('localStorage.clear();sessionStorage.clear()');
  await w.loadURL('http://127.0.0.1:5194/tests/wall-mobile.html?host='+host);await wait(850);await js(`document.querySelector('.mv-wall-card[data-wall-id="0"]').click()`);await wait(650);
  if(host==='ios'){
   await js(`window.pinch=(type,distance)=>{const wall=document.querySelector('.mv-cover-wall'),touches=type==='touchend'?[]:[new Touch({identifier:1,target:wall,clientX:180-distance/2,clientY:420}),new Touch({identifier:2,target:wall,clientX:180+distance/2,clientY:420})];wall.dispatchEvent(new TouchEvent(type,{bubbles:true,cancelable:true,touches,targetTouches:touches,changedTouches:touches}));};pinch('touchstart',100)`);
   for(const d of [30,200,35,180]){await js(`pinch('touchmove',${d})`);await wait(100);assert.ok(await js(`(()=>{const c=document.querySelector('.mv-wall-focus-content');return getComputedStyle(c).transform==='none'&&parseFloat(getComputedStyle(c.querySelector('h1')).fontSize)<=26.01&&[...c.querySelectorAll('.mv-synced-line')].every(n=>parseFloat(getComputedStyle(n).fontSize)<=34.01)})()`),'pinch must respect text upper bounds without scaling a frozen layout');}
   await js(`pinch('touchend',0)`);await wait(250);
  }
  await js(`document.querySelector('[aria-label="展开播放器"]').click()`);await wait(850);
  assert.ok(await js(`(()=>{const n=document.querySelector('.wp-controls'),a=n.querySelector('.wp-kinetic-toggle').getBoundingClientRect(),b=n.querySelector('.artwork-mode-toggle').getBoundingClientRect(),c=n.querySelector('.wp-collapse-toggle').getBoundingClientRect();return b.left-a.right<16&&c.left-b.right<16&&Math.abs(c.right-n.getBoundingClientRect().right)<2})()`),host+' three trailing actions must be one right-aligned group');
  await js(`document.querySelector('[aria-label="切换高斯模糊插图"]').click()`);await wait(500);
  assert.ok(await js(`(()=>{const n=document.querySelector('.mv-wall-artwork-stack'),sharp=[...n.querySelectorAll('img')].find(i=>!i.classList.contains('mv-artwork-blur')&&i.naturalWidth),blur=n.querySelector('.mv-artwork-blur');return blur.naturalWidth&&getComputedStyle(blur).objectPosition===getComputedStyle(sharp).objectPosition&&Math.abs(blur.getBoundingClientRect().width-sharp.getBoundingClientRect().width)<1})()`),host+' blur must reuse sharp crop');
  console.log('PASS '+host+' pinch typography, trailing actions and blur crop');
 }
 w.setContentSize(440,900);await w.loadURL('http://127.0.0.1:5194/tests/wall-desktop.html');await wait(850);
 await js(`desktopWallFixture.state.subjectRegions=[{x:.8,y:.2,width:.15,height:.2,face:1}];document.querySelector('.wall-poster[data-track-id="1"]').click()`);await wait(900);
 assert.ok(await js(`desktopWallFixture.calls.some(c=>c.name==='artworkSubjects'&&c.payload.id==='1')`),'Mac must call native subject analysis');
 await js(`miniVoice.command('play',{id:'1'})`);await wait(450);await js(`document.querySelector('.wall-poster.focused [aria-label="展开播放器"]').click()`);await wait(850);
 const focal=await js(`document.querySelector('.wall-poster.focused img.cover').dataset.focalX`);assert.ok(+focal>.7,'Mac subject crop must protect the right-side face');
 await js(`document.querySelector('.wall-poster.focused .artwork-mode-toggle').click()`);await wait(500);
 assert.ok(await js(`(()=>{const n=document.querySelector('.wall-poster.focused'),a=n.querySelector('img.cover'),b=n.querySelector('.mv-artwork-blur');return b.naturalWidth&&['width','height','transform','transformOrigin','objectPosition'].every(k=>getComputedStyle(a)[k]===getComputedStyle(b)[k])})()`),'Mac blur must reuse the exact sharp presentation');
 console.log('PASS Mac native subject request, off-center subject crop and identical clear/blur geometry');w.destroy();app.exit(0);
}catch(e){console.error(e);w?.destroy();app.exit(1)}});
