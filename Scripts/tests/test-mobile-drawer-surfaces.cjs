const {app,BrowserWindow}=require('electron'),fs=require('node:fs'),path=require('node:path');
app.setPath('userData',fs.mkdtempSync(path.join(require('node:os').tmpdir(),'mv-drawer-material-')));app.on('window-all-closed',()=>{});
const out=path.resolve(__dirname,'../../.build/reports/ui');fs.mkdirSync(out,{recursive:true});
let win;const wait=ms=>new Promise(r=>setTimeout(r,ms)),check=(v,m)=>{if(!v)throw Error(m)},js=s=>win.webContents.executeJavaScript(s,true);
const until=async(s,m)=>{for(let i=0;i<100;i++){if(await js(s))return;await wait(50);}throw Error(m)};
const click=async s=>{await js(`document.querySelector(${JSON.stringify(s)}).click();true`);await wait(400)};
const surfaceProbe=`(()=>{const selectors=['.mv-toolbar>.mv-button','.mv-search-control','.mv-lyrics','.mv-dock','.mv-library'];return selectors.flatMap(selector=>[...document.querySelectorAll('.mv-scene '+selector)].filter(n=>n.getClientRects().length).map(n=>{const s=getComputedStyle(n);return {selector,background:s.backgroundColor,image:s.backgroundImage,border:s.borderTopColor,borderWidth:s.borderTopWidth,shadow:s.boxShadow,blur:s.backdropFilter,radius:s.borderRadius}}))})()`;
const silhouette=rows=>rows.map(({shadow,blur,...shape})=>shape);
const timeout=setTimeout(()=>{console.error('Drawer surface test timed out');app.exit(1)},120000);
app.whenReady().then(async()=>{try{
 for(const host of ['android','ios']){
  win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false,partition:'drawer-'+host}});
  await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5199')+'/tests/wall-mobile.html?host='+host);await until("!!document.querySelector('.mv-wall-card')",'Wall fixture unavailable');
  for(const style of ['simple','library']){
   await click('[aria-label=打开侧边栏]');
   while(await js("document.querySelector('main').dataset.style!=="+JSON.stringify(style))){await click('.mv-brand-logo');await until("document.querySelector('main').dataset.styleBusy==='false'",'Style switch pending');}
   await click('[aria-label=关闭侧边栏]');
   if(style==='library')await click('.mv-list-tools [aria-label=正在播放]');
   for(const theme of ['light','dark']){
    await click('[aria-label=打开侧边栏]');await click('.mv-drawer [aria-label=设置]');
    await js(`Array.from(document.querySelectorAll('.mv-mobile-settings button')).find(n=>n.textContent.startsWith(${JSON.stringify(theme==='light'?'浅色模式':'深色模式')})).click();true`);await wait(200);await click('[aria-label=关闭弹窗]');
    for(const landscape of [false,true]){
     win.setContentSize(...(landscape?[844,390]:[390,844]));await wait(450);
     const before=await js(surfaceProbe);check(before.some(s=>s.selector==='.mv-lyrics')&&before.some(s=>s.selector==='.mv-dock'),'Playback blocks missing');
     check(before.filter(s=>s.selector==='.mv-search-control').every(s=>s.background!=='rgba(0, 0, 0, 0)'||s.image!=='none'),'Fixture lacks drawn surfaces');
     await click('[aria-label=打开侧边栏]');const during=await js(surfaceProbe);
     check(JSON.stringify(silhouette(before))===JSON.stringify(silhouette(during)),`Drawer changed component material: ${host}/${style}/${theme}/${landscape}`);
     check(during.every(s=>s.shadow==='none'&&s.blur==='none'),'Recessed content still samples nested backdrops or casts shadows');
     check(await js("document.querySelector('.mv-scene').inert&&Number(new DOMMatrixReadOnly(getComputedStyle(document.querySelector('.mv-scene')).transform).a)<1&&!!document.querySelector('.mv-drawer-shade')"),'Drawer lost recess/scrim/input isolation');
     if(!landscape&&theme==='light')fs.writeFileSync(path.join(out,`drawer-surface-${host}-${style}.png`),(await win.webContents.capturePage()).toPNG());
     await click('[aria-label=关闭侧边栏]');check(JSON.stringify(before)===JSON.stringify(await js(surfaceProbe)),'Closing drawer changed material');
     console.log(`PASS ${host} ${style} ${theme} ${landscape?'landscape':'portrait'} preserves material before/open/closed and blocks background input`);
    }
   }
  }
  win.destroy();win=null;
 }
 clearTimeout(timeout);app.exit(0);
 }catch(e){console.error(e.stack);win?.destroy();clearTimeout(timeout);app.exit(1)}});
