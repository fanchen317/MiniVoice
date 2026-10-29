const {app,BrowserWindow}=require('electron'),fs=require('node:fs'),path=require('node:path');
const out=path.resolve(__dirname,'../../.build/reports/ui');fs.mkdirSync(out,{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.join(require('node:os').tmpdir(),'mv-chrome-')));
app.on('window-all-closed',()=>{});
let win,stage='starting';const wait=ms=>new Promise(r=>setTimeout(r,ms));
const check=(value,message)=>{if(!value)throw Error(message)};
const js=source=>win.webContents.executeJavaScript(source,true);
const until=async(source,message)=>{for(let i=0;i<100;i++){if(await js(source))return;await wait(50);}throw Error(message)};
const click=async selector=>{await js(`document.querySelector(${JSON.stringify(selector)}).click();true`)};
const selectors=['.mv-toolbar>[aria-label=打开侧边栏]','.mv-search-control','[data-wall-control=settings]','.mv-wall-dock'];
const probe=`(()=>{const nodes=${JSON.stringify(selectors)}.map(s=>document.querySelector(s));return {phase:document.querySelector('main').dataset.wallChrome,compact:nodes[3].classList.contains('is-compact'),same:nodes[3]===window.retainedDock,rects:nodes.map(n=>{const r=n.getBoundingClientRect(),s=getComputedStyle(n);return {x:r.x,y:r.y,right:r.right,bottom:r.bottom,width:r.width,height:r.height,opacity:Number(s.opacity),visibility:s.visibility,display:s.display,inert:n.inert||!!n.closest('[inert]')}})}})()`;
const timeout=setTimeout(()=>{console.error('TIMEOUT '+stage);app.exit(1);},180000);
app.whenReady().then(async()=>{try{
 for(const host of (process.env.MV_CHROME_HOST?[process.env.MV_CHROME_HOST]:process.env.MV_CHROME_ONE?['android']:['android','ios']))for(const landscape of (process.env.MV_CHROME_ONE?[false]:[false,true]))for(const compact of (process.env.MV_CHROME_ONE?[false]:[false,true])){
  stage=`${host}/${landscape}/${compact} create`;console.log(stage);
  win=new BrowserWindow({show:false,width:landscape?844:390,height:landscape?390:844,webPreferences:{backgroundThrottling:false,partition:`chrome-${host}-${landscape}-${compact}`}});
  win.webContents.on('console-message',(_event,_level,message)=>{if(/Error|error|Uncaught/.test(message||''))console.error(message);});
  stage+=' load';await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5196')+`/tests/wall-mobile.html?host=${host}`);
  stage+=' ready';await until("!!document.querySelector('.mv-wall-card')",'Wall missing');await click('.mv-wall-card[data-wall-id="0"]');await wait(550);
  if(compact){await until("document.querySelector('.mv-wall-dock').classList.contains('is-compact')",'Dock never collapsed');await wait(450);}
  else if(await js("document.querySelector('.mv-wall-dock').classList.contains('is-compact')")){await click('.wp-dock-meter');await wait(450);}
  await js("window.retainedDock=document.querySelector('.mv-wall-dock');true");const before=await js(probe);
  stage+=' expand';await click('.mv-wall-focused [aria-label=展开播放器]');await wait(100);const mid=await js(probe);
  check(mid.same&&mid.compact===compact,'Dock shape reset at exit');
  check(mid.rects.every((r,i)=>r.display!=='none'&&r.visibility==='visible'&&r.opacity>0&&r.opacity<1&&(i===0?r.x<before.rects[i].x:i===1?r.x>before.rects[i].x:r.y>before.rects[i].y)),'Four controls lack directional intermediate travel: '+JSON.stringify({before,mid}));
  await wait(380);let hidden=await js(probe);check(hidden.rects.every(r=>r.visibility==='hidden'&&r.inert),'Hidden chrome is still interactive');
  check(hidden.rects[0].right<0&&hidden.rects[1].x>await js('innerWidth')&&hidden.rects.slice(2).every(r=>r.y>before.rects[3].bottom),'Chrome failed to leave screen');
  if(host==='ios'&&!landscape){await wait(3200);check((await js(probe)).compact===compact,'Hidden idle timer changed dock shape');}
  const original=win.getSize();win.setSize(original[1],original[0]);await wait(300);win.setSize(...original);await wait(400);check((await js(probe)).compact===compact,'Rotation changed concealed dock shape');
  await js("window.dispatchEvent(new Event('minivoice-back'));true");await wait(100);check((await js(probe)).phase==='hidden','Chrome returned before artwork collapsed');
  await wait(360);const entering=await js(probe);check(entering.phase==='entering'&&entering.rects.every(r=>r.opacity>0&&r.opacity<1),'Return lacks intermediate frames');
  await wait(400);const restored=await js(probe);check(restored.same&&restored.compact===compact&&restored.phase==='visible','Dock shape/node not restored');
  check(restored.rects.every((r,i)=>Math.abs(r.x-before.rects[i].x)<1&&Math.abs(r.y-before.rects[i].y)<1),'Chrome did not regain original layout: '+JSON.stringify({before,restored}));
  // Reverse twice inside the card/chrome motion; no old return timer may win.
  await click('.mv-wall-focused [aria-label=展开播放器]');await wait(80);await js("window.dispatchEvent(new Event('minivoice-back'));true");await wait(80);await click('.mv-wall-focused [aria-label=展开播放器]');await wait(850);check((await js(probe)).phase==='hidden','Interrupted return resurrected chrome');
  win.webContents.debugger.attach('1.3');await win.webContents.debugger.sendCommand('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
  await js("window.dispatchEvent(new Event('minivoice-back'));true");await wait(70);check((await js(probe)).phase==='visible','Reduced motion kept a delayed return');
  stage+=' screenshot';console.log(stage);
  fs.writeFileSync(path.join(out,`chrome-${host}-${landscape?'landscape':'portrait'}-${compact?'circle':'bar'}.png`),(await win.webContents.capturePage()).toPNG());
  console.log(`PASS ${host} ${landscape?'landscape':'portrait'} ${compact?'circle':'bar'} travel, retained state, return, interruption and reduced motion`);win.destroy();win=null;
 }
 clearTimeout(timeout);app.exit(0);
 }catch(error){console.error(error.stack);if(win&&!win.isDestroyed()){const shot=await Promise.race([win.webContents.capturePage().catch(()=>null),wait(1000).then(()=>null)]);if(shot)fs.writeFileSync(path.join(out,'wall-chrome-failure.png'),shot.toPNG());win.destroy();}clearTimeout(timeout);app.exit(1);}});
