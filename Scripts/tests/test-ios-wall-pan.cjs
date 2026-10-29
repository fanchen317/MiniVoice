const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});
 const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5194/tests/wall-mobile.html?host=ios');
 for(let i=0;i<100;i++){if(await js("document.querySelector('.mv-wall-plane')?.dataset.compositedPan==='true'"))break;await pause(100);}
 assert.equal(await js("document.querySelector('.mv-wall-plane')?.dataset.compositedPan"),'true');
 const before=await js("(()=>{const n=[...document.querySelectorAll('.mv-wall-card')].find(n=>{const r=n.getBoundingClientRect();return r.left>=0&&r.right<innerWidth&&r.top>100&&r.top<innerHeight-200;});if(!n)throw Error('No visible poster');const r=n.getBoundingClientRect();window.panProbe=n;return {x:r.x,y:r.y}})()");
 await js("document.addEventListener('wheel',e=>window.panWheel={x:e.deltaX,y:e.deltaY},{capture:true,once:true})");
 // Wheel input exercises the same live camera while avoiding kinetic release displacement.
 win.webContents.sendInputEvent({type:'mouseWheel',x:220,y:330,deltaX:-70,deltaY:-25});await pause(50);
 const during=await js("(()=>{const r=panProbe.getBoundingClientRect();return {x:r.x,y:r.y,loaded:panProbe.querySelector('img').naturalWidth>0,wheel:window.panWheel}})()");
 assert.ok(during.wheel&&Math.abs(during.wheel.x)>0);assert.ok(Math.abs(during.x-before.x+during.wheel.x)<2,JSON.stringify({before,during}));assert.ok(Math.abs(during.y-before.y+during.wheel.y)<2);assert.ok(during.loaded);
 await pause(500);
 const after=await js("(()=>{const r=panProbe.getBoundingClientRect();return {x:r.x,y:r.y}})()");
 assert.ok(Math.abs(after.x-during.x)<2,'camera commit jumps horizontally');assert.ok(Math.abs(after.y-during.y)<2,'camera commit jumps vertically');
 assert.equal(await js("getComputedStyle(document.querySelector('.mv-wall-caption')).webkitUserSelect"),'none');
 fs.mkdirSync('.build/reports/ios/touch-performance',{recursive:true});fs.writeFileSync('.build/reports/ios/touch-performance/pan.png',(await win.webContents.capturePage()).toPNG());
 console.log('PASS iOS camera projection, decoded posters, commit continuity and selection policy');app.exit(0);
}catch(e){console.error(e);app.exit(1);}});
