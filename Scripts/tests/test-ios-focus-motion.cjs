const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict'),fs=require('node:fs');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false}});const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL(process.env.MV_FOCUS_URL||'http://127.0.0.1:5202/tests/wall-mobile.html?host=ios');await wait(1000);
 await js("window.posterSizes=0;window.sizeWatch=new MutationObserver(records=>{for(const record of records){const n=record.target;if(!n.matches('.mv-wall-card'))continue;const old=record.oldValue||'',now=n.getAttribute('style')||'';const size=s=>(s.match(/(?:^|;)\\s*(?:width|height):[^;]+/g)||[]).join('');if(size(old)!==size(now))posterSizes++;}});sizeWatch.observe(document.querySelector('.mv-wall-plane'),{attributes:true,attributeOldValue:true,subtree:true,attributeFilter:['style']});window.motionCell=[...document.querySelectorAll('.mv-wall-card')].find(n=>{const r=n.getBoundingClientRect();return r.left>0&&r.right<innerWidth&&r.top>100&&r.bottom<innerHeight-100;});if(!motionCell)throw Error('No full poster');motionCell.click()");
 await wait(100);const start=await js('posterSizes');await wait(230);const focusWrites=await js('posterSizes-startValue'.replace('startValue',String(start)));
 if(!process.env.MV_FOCUS_BASELINE)assert.ok(focusWrites<6,'Reflow kept resizing posters: '+focusWrites);
 const scales=await js("(()=>{const image=document.querySelector('.mv-wall-focused-art'),m=new DOMMatrixReadOnly(getComputedStyle(image).transform),root=new DOMMatrixReadOnly(getComputedStyle(image.parentElement).transform);return {x:Math.hypot(m.a,m.b)*Math.hypot(root.a,root.b),y:Math.hypot(m.c,m.d)*Math.hypot(root.c,root.d)}})()");
 if(!process.env.MV_FOCUS_BASELINE)assert.ok(Math.abs(scales.x-scales.y)<.02,'Artwork stretched during focus');
 await wait(350);
 // Double activation must start playback and finish at a square, even during reflow.
 await js("document.querySelector('.mv-wall-card[data-wall-id=\"2\"]').click()");await wait(80);await js("document.querySelector('.mv-wall-card[data-wall-id=\"2\"]').click()");await wait(750);
 assert.equal(await js('wallFixture.state.current'),'2');assert.equal(await js('wallFixture.state.playing'),true);
 const error=await js("(()=>{const r=document.querySelector('.mv-wall-focused').getBoundingClientRect();return Math.abs(r.width-r.height)})()");assert.ok(error<1.5,'Focus did not finish square');
 await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(70);const before=await js('posterSizes');await wait(180);const drawerWrites=await js('posterSizes-'+before);
 if(!process.env.MV_FOCUS_BASELINE)assert.equal(drawerWrites,0,'Drawer depth resized posters');
 await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(500);
 assert.equal(await js("getComputedStyle(document.querySelector('.mv-wall-focused-art')).visibility"),'visible');
 await js("[...document.querySelectorAll('.mv-wall-card')].find(n=>n.dataset.wallId!=='2').click()");await wait(100);
 await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(400);
 await js("document.querySelector('[aria-label=关闭侧边栏]').click()");await wait(800);
 const resumed=await js("(()=>{const r=document.querySelector('.mv-wall-focused').getBoundingClientRect();return Math.abs(r.width-r.height)})()");assert.ok(resumed<1.5,'Interrupted focus remained half-shaped after drawer return');
 assert.equal(await js("[...document.querySelectorAll('.mv-wall-card')].reduce((sum,n)=>sum+n.getAnimations().length,0)"),0,'Reflow animations leaked');
 fs.mkdirSync('.build/reports/ios/focus-motion',{recursive:true});fs.writeFileSync('.build/reports/ios/focus-motion/'+(process.env.MV_FOCUS_BASELINE?'baseline':'optimized')+'.json',JSON.stringify({focusWrites,drawerWrites,scales,error},null,2));
 console.log('PASS focus square, artwork aspect, double-play, drawer return; geometry writes '+JSON.stringify({focusWrites,drawerWrites}));win.destroy();app.exit(0);
 }catch(error){console.error(error);win?.destroy();app.exit(1);}});
