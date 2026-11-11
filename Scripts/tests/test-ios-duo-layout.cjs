const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const output=path.resolve('.build/reports/ui/ios-duo');fs.mkdirSync(output,{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/duo-profile-')));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:600,height:900,useContentSize:true,webPreferences:{backgroundThrottling:false}});
 const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5309')+'/tests/wall-mobile.html?host=ios');
 for(let i=0;i<80;i++){if(await js("document.querySelector('main')?.dataset.ready==='true'"))break;await pause(100);}
 await js("window.miniVoiceFold={duo:true,top:0,bottom:0};dispatchEvent(new Event('minivoice-insets'));wallFixture.state.scanning=true;wallFixture.state.scanTotal=100;wallFixture.state.scanCompleted=25");await pause(1200);
 const results=[];
 for(const size of [[600,900],[900,600],[440,956]]){
  win.setContentSize(...size);
  for(const theme of ['dark','light'])for(const side of ['left','right','none']){
   await js(`(()=>{const m=document.querySelector('main');m.classList.remove('theme-dark','theme-light');m.classList.add('theme-${theme}');for(const s of ['top','bottom','left','right'])m.style.setProperty('--mv-safe-'+s,(s==='bottom'?34:s==='${side}'?80:0)+'px');dispatchEvent(new Event('minivoice-insets'));})()`);await pause(1100);
   const r=await js(`(()=>{const rect=s=>{const r=document.querySelector(s).getBoundingClientRect();return {left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width}};return {overlap:document.querySelector('main').dataset.dockOverlap,scan:rect('.mv-scan-status'),dock:rect('.mv-wall-dock'),settings:rect('[data-wall-control=settings]'),toolbar:rect('.mv-toolbar'),menu:rect('.mv-toolbar>.mv-button'),search:rect('.mv-search-control')}})()`);
   const left=side==='left'?80:0,right=side==='right'?80:0;
   assert.ok(Math.abs((r.scan.left+r.scan.right)/2-(size[0]+left-right)/2)<1,'scan content center');
   const bottom=side!=='none'?14:48;
   assert.ok(Math.abs(size[1]-r.settings.bottom-bottom-(r.overlap==='true'&&size[0]<size[1]?98:0))<1,JSON.stringify({size,side,r,bottom}));
   assert.ok(Math.abs(size[1]-r.dock.bottom-bottom)<1,'dock bottom');
   assert.ok(r.scan.left>=left&&r.scan.right<=size[0]-right,'scan within safe region');
   assert.ok(Math.abs(r.menu.top-r.search.top)<1&&Math.abs(r.menu.width-r.search.width)<1,'equal top control geometry');
   assert.ok(Math.abs(r.settings.right-r.search.right)<1,'right control axis');
   if(r.dock.width===56)assert.ok(Math.abs(r.dock.left-r.menu.left)<1,'left control axis');
   results.push({size,theme,side,...r});
   if(size[0]===600&&theme==='dark'&&side==='right')fs.writeFileSync(path.join(output,'duo.png'),(await win.webContents.capturePage()).toPNG());
  }
 }
 win.setContentSize(956,440);await js("window.miniVoiceFold={duo:false,top:0,bottom:0};const m=document.querySelector('main');m.style.setProperty('--mv-safe-left','59px');m.style.setProperty('--mv-safe-right','0px');m.style.setProperty('--mv-safe-bottom','21px');dispatchEvent(new Event('minivoice-insets'))");await pause(1100);
 assert.ok(await js("Math.abs(440-document.querySelector('[data-wall-control=settings]').getBoundingClientRect().bottom-35)<1"),'ordinary iPhone landscape retains Home clearance');
 await js("document.querySelector('.mv-scan-status').click()");await pause(1100);
 assert.ok(await js("!!document.querySelector('.mv-modal-shade')"),'scan opens settings');
 fs.writeFileSync(path.join(output,'geometry.json'),JSON.stringify(results,null,2));console.log('PASS Duo portrait, rotation, left/right status strips, ordinary iPhone Home clearance, dark/light, scan action');win.destroy();app.exit(0);
 }catch(e){console.error(e);win?.destroy();app.exit(1);}});
