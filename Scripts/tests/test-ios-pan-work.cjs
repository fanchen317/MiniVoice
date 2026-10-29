const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict'),fs=require('node:fs');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5202/tests/wall-mobile.html?host=ios');await wait(1200);
 await js("window.panWrites=0;window.wallNodes=new Map([...document.querySelectorAll('.mv-wall-card')].map(n=>[n.dataset.wallCell,n]));window.panObserver=new MutationObserver(records=>panWrites+=records.filter(r=>wallNodes.get(r.target.dataset.wallCell)===r.target).length);panObserver.observe(document.querySelector('.mv-wall-plane'),{subtree:true,attributes:true,attributeFilter:['style']});window.beforeRenders=wallFixture.renders");
 for(let i=0;i<16;i++){
  await js(`document.querySelector('.mv-cover-wall').dispatchEvent(new WheelEvent('wheel',{deltaX:${i<8?80:-80},deltaY:0,bubbles:true,cancelable:true}))`);await wait(35);
  assert.equal(await js("(async()=>{const {createScene,visibleTiles}=await import('/src/wallGeometry.js'),p=document.querySelector('.mv-wall-plane'),c=JSON.parse(p.dataset.camera),mounted=new Set([...p.children].map(n=>n.dataset.wallCell));return visibleTiles(createScene(1037),c,{width:innerWidth,height:innerHeight},0).filter(cell=>!mounted.has(cell.id)).length})()"),0,'Visible coverage lost');
 }
 await wait(250);const result=await js('({posterStyleWrites:panWrites,reactCommits:wallFixture.renders-beforeRenders,camera:JSON.parse(document.querySelector(".mv-wall-plane").dataset.camera)})');
 if(!process.env.MV_PAN_BASELINE)assert.ok(result.posterStyleWrites<20,'Pan rebased existing posters: '+JSON.stringify(result));
 fs.mkdirSync('.build/reports/ios/pan-work',{recursive:true});fs.writeFileSync('.build/reports/ios/pan-work/'+(process.env.MV_PAN_BASELINE?'baseline':'optimized')+'.json',JSON.stringify(result,null,2));
 // Cross bounded raster origins in both directions and verify actual projection, not just IDs.
 for(let i=0;i<32;i++){
  await js(`document.querySelector('.mv-cover-wall').dispatchEvent(new WheelEvent('wheel',{deltaX:${i<16?160:-160},deltaY:${i<16?45:-45},bubbles:true,cancelable:true}))`);await wait(35);
  const error=await js("(async()=>{const {createScene,visibleTiles}=await import('/src/wallGeometry.js'),plane=document.querySelector('.mv-wall-plane'),camera=JSON.parse(plane.dataset.camera),tiles=visibleTiles(createScene(1037),camera,{width:innerWidth,height:innerHeight},0);let error=0;for(const tile of tiles){const node=[...plane.children].find(n=>n.dataset.wallCell===tile.id);if(!node)return 1e6;const r=node.getBoundingClientRect();error=Math.max(error,Math.abs(r.x-camera.x-tile.x*camera.scale),Math.abs(r.y-camera.y-tile.y*camera.scale));}return error})()");
  assert.ok(error<1,'Raster origin handoff moved a visible card: '+error);
 }
 await wait(250);
 console.log('PASS bounded pan, reverse, visible coverage '+JSON.stringify(result));win.destroy();app.exit(0);
}catch(error){console.error(error);win?.destroy();app.exit(1);}});
