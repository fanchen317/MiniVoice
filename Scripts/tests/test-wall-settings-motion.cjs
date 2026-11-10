// Real touch release and every animation frame: final layout is independent of button feedback.
const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5317';
const output=path.resolve('.build/reports/ui/wall-settings-motion');fs.mkdirSync(output,{recursive:true});fs.mkdirSync('.build/work',{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/settings-motion-profile-')));
app.on('window-all-closed',()=>{});
const baseline=process.env.MINIVOICE_SETTINGS_MOTION_BASELINE==='1';
const deadline=setTimeout(()=>{console.error('Wall settings motion timed out');app.exit(1);},120000);
app.whenReady().then(async()=>{let win;const results=[];try{
 win=new BrowserWindow({show:false,width:956,height:440,useContentSize:true,webPreferences:{backgroundThrottling:false}});
 const js=async source=>{try{return await win.webContents.executeJavaScript(source,true);}catch(error){throw Error('Renderer: '+source,{cause:error});}};
 const until=async(source,label)=>{for(let i=0;i<100;i++){if(await js(source))return;await wait(50);}throw Error(label);};
 async function load(host,side,theme='dark',reduced=false){
  win.setContentSize(956,440);
  if(win.webContents.getURL().startsWith(base))await js("localStorage.removeItem('wall-fixture-v2');sessionStorage.removeItem('wall-fixture-started');true");
  await win.loadURL(base+'/tests/wall-mobile.html?host='+host);
  await until("document.querySelector('main')?.dataset.ready==='true'&&document.querySelector('.mv-wall-card')",'Fixture not ready');
  if(!win.webContents.debugger.isAttached())win.webContents.debugger.attach('1.3');
  await win.webContents.debugger.sendCommand('Emulation.setTouchEmulationEnabled',{enabled:true});
  await js(`document.documentElement.classList.toggle('reduce-motion',${reduced});document.querySelector('main').style.cssText+=';--mv-safe-${side}:59px;--mv-safe-${side==='left'?'right':'left'}:0px;--mv-safe-bottom:21px';window.dispatchEvent(new Event('minivoice-insets'));true`);
  await wait(420);
  if(theme==='light'){
   await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(430);
   await js("document.querySelector('.mv-drawer [aria-label=设置]').click()");await wait(100);
   await js("[...document.querySelectorAll('.mv-mobile-settings button')].find(node=>node.textContent.startsWith('浅色模式')).click()");await wait(90);
   await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(340);
   assert.equal(await js("document.querySelector('main').dataset.theme"),'light');
  }
 }
 async function arm(){await js(`(()=>{window.settingsMotion?.observer?.disconnect();if(window.settingsMotion)settingsMotion.stop=true;const probe=window.settingsMotion={frames:[],mutations:[],start:performance.now(),stop:false};const rect=node=>{if(!node)return null;const r=node.getBoundingClientRect();return {left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:r.width,height:r.height}};probe.observer=new MutationObserver(changes=>{for(const change of changes)if(change.target.matches('.mv-modal'))probe.mutations.push({time:performance.now()-probe.start,style:change.target.getAttribute('style')})});probe.observer.observe(document.querySelector('main'),{subtree:true,attributes:true,attributeFilter:['style']});function sample(){const panel=document.querySelector('.mv-modal-shade[data-modal-variant=wall-settings]>.mv-modal'),button=document.querySelector('[aria-label=音乐墙设置]'),search=document.querySelector('.mv-toolbar>.mv-search-control');if(panel)probe.frames.push({time:performance.now()-probe.start,style:Object.fromEntries(['width','right','bottom','height','maxHeight'].map(key=>[key,panel.style[key]])),layout:{left:panel.offsetLeft,top:panel.offsetTop,width:panel.offsetWidth,height:panel.offsetHeight},panel:rect(panel),button:rect(button),buttonScale:getComputedStyle(button).scale,search:rect(search),transform:getComputedStyle(panel).transform});if(!probe.stop)requestAnimationFrame(sample)}requestAnimationFrame(sample);})()`);}
 async function realTap(selector){
  const point=await js(`(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()`);
  await win.webContents.debugger.sendCommand('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point,id:1}]});await wait(70);
  await win.webContents.debugger.sendCommand('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 }
 async function finishProbe(label){
  const probe=await js("(()=>{settingsMotion.stop=true;settingsMotion.observer.disconnect();return {frames:settingsMotion.frames,mutations:settingsMotion.mutations}})()");
  assert.ok(probe.frames.length>10,'Not enough opening frames: '+label);
  const ranges=Object.fromEntries(['width','right','bottom','height','maxHeight'].map(key=>{const values=probe.frames.map(row=>parseFloat(row.style[key])).filter(Number.isFinite);return [key,{min:Math.min(...values),max:Math.max(...values),distinct:new Set(values).size}]}));
  const last=probe.frames.at(-1),summary={label,ranges,styleWrites:probe.mutations.length,lateStyleWrites:probe.mutations.filter(value=>value.time>300).length,final:{panel:last.panel,button:last.button,search:last.search},probe};results.push(summary);
  fs.writeFileSync(path.join(output,label+'.json'),JSON.stringify(summary,null,2));
  fs.writeFileSync(path.join(output,label+'.png'),(await win.webContents.capturePage()).toPNG());
  return summary;
 }
 function anchored(last,label){
  assert.ok(Math.abs(last.panel.top-last.search.top)<.6,`${label}: top misses search ${last.panel.top} vs ${last.search.top}`);
  assert.ok(Math.abs(last.panel.right-last.search.right)<.6,`${label}: right misses search`);
  assert.ok(Math.abs(last.panel.right-last.button.right)<.6&&Math.abs(last.panel.bottom-last.button.bottom)<.6,`${label}: bottom corner misses settings button`);
 }
 function opening(summary,{reduced=false}={}){
  const {label,probe,ranges,final}=summary;
  for(const key of ['width','right','bottom','height','maxHeight'])assert.ok(ranges[key].distinct>0&&ranges[key].max-ranges[key].min<.05,`${label}: ${key} layout changed while button released: ${JSON.stringify(ranges[key])}`);
  assert.equal(summary.lateStyleWrites,0,`${label}: idle opening still rewrites layout`);
  assert.ok(summary.styleWrites<=8,`${label}: repeated opening geometry writes ${summary.styleWrites}`);
  // Bottom-right anchored scale can move only the top/left edges, monotonically.
  for(const frame of probe.frames){assert.ok(Math.abs(frame.panel.right-final.panel.right)<.6&&Math.abs(frame.panel.bottom-final.panel.bottom)<.6,`${label}: visual anchor moved`);}
  for(let i=1;i<probe.frames.length;i++)assert.ok(probe.frames[i].panel.width+.15>=probe.frames[i-1].panel.width,`${label}: scale reversed at frame ${i}`);
  if(reduced)assert.ok(probe.frames.every(frame=>frame.transform==='none'),`${label}: reduced motion animates`);
  else assert.ok(probe.frames.some(frame=>Math.abs(parseFloat(frame.buttonScale)-1)>.015),`${label}: button feedback positive control missing`);
  anchored(final,label);
 }
 async function searchProbe(host){
  await load(host,'left');await realTap('[aria-label=搜索音乐]');await wait(850);await arm();await realTap('[aria-label=音乐墙设置]');await wait(800);
  const summary=await finishProbe(host+'-search-open');opening(summary);assert.equal(summary.lateStyleWrites,0,'Closing search still moves popup');
  console.log('PASS '+host+' opened search closing while settings anchors remain stable');
  await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(300);
 }
 if(process.env.MINIVOICE_SETTINGS_MOTION_SEARCH_ONLY==='1'){for(const host of ['ios','android'])await searchProbe(host);
 }else if(baseline){
  await load('ios','left');await arm();await realTap('[aria-label=音乐墙设置]');await wait(800);
  const summary=await finishProbe('baseline');console.log(JSON.stringify({ranges:summary.ranges,styleWrites:summary.styleWrites,gap:summary.final.panel.top-summary.final.search.top},null,2));
 }else{
  for(const host of ['ios','android'])for(const side of ['left','right'])for(const theme of ['dark','light']){
   await load(host,side,theme);await arm();await realTap('[aria-label=音乐墙设置]');await wait(800);
   const label=`${host}-${side}-${theme}`;opening(await finishProbe(label));console.log('PASS '+label+' stable touch opening and corner coverage');
   await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(300);
  }
  for(const host of ['ios','android']){
   await searchProbe(host);
   await load(host,'left');
   for(const elapsed of [50,290]){
    await realTap('[aria-label=音乐墙设置]');await wait(elapsed);
    const continuity=await js(`(async()=>{const read=node=>{const r=node.getBoundingClientRect();return {left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:r.width,height:r.height,offsetWidth:node.offsetWidth,offsetHeight:node.offsetHeight}};const before=read(document.querySelector('.mv-modal'));document.querySelector('[aria-label=关闭弹窗]').click();await Promise.resolve();const ghost=document.querySelector('[data-surface-exit=modal] .mv-modal');return {before,after:ghost&&read(ghost)};})()`);
    assert.ok(continuity.after,host+' closing ghost missing');
    for(const edge of ['width','height','right','bottom'])assert.ok(Math.abs(continuity.before[edge]-continuity.after[edge])<.7,`${host} close at ${elapsed}ms jumped ${edge}: ${JSON.stringify(continuity)}`);
    results.push({label:host+'-exit-'+elapsed,continuity});
    await realTap('[aria-label=音乐墙设置]');await wait(420);
    assert.equal(await js("document.querySelectorAll('[data-surface-exit=modal]').length"),0,'Reopening retained stale ghost');
    await arm();await wait(360);anchored((await finishProbe(host+'-rapid-'+elapsed)).final,host+' rapid reopen');
    await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(300);
   }
   await realTap('[aria-label=音乐墙设置]');await wait(420);
   for(const cancel of [false,true]){
    const point=await js("(()=>{const r=document.querySelector('.mv-modal-grip').getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()");
    await win.webContents.debugger.sendCommand('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point,id:1}]});await wait(60);
    await win.webContents.debugger.sendCommand('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:point.x,y:point.y+20,id:1}]});await wait(50);
    await win.webContents.debugger.sendCommand('Input.dispatchTouchEvent',{type:cancel?'touchCancel':'touchEnd',touchPoints:[]});await wait(300);
    await arm();await wait(360);const settled=await finishProbe(host+'-handle-'+(cancel?'cancel':'release'));anchored(settled.final,host+' handle settle');assert.ok(settled.ranges.height.distinct>0,'Handle settlement lost controlled height');assert.equal(settled.styleWrites,0,'Handle settle relies on layout polling to restore height');
   }
   await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(300);
  }
  for(const host of ['ios','android']){
   await load(host,'right','dark',true);await arm();await realTap('[aria-label=音乐墙设置]');await wait(700);
   opening(await finishProbe(host+'-reduced'),{reduced:true});
   await js("document.querySelector('[aria-label=关闭弹窗]').click()");await wait(30);
   await arm();await realTap('[aria-label=音乐墙设置]');await wait(50);
   await js("document.querySelector('[aria-label=关闭弹窗]').click();document.querySelector('[aria-label=音乐墙设置]').click()");await wait(420);
   const reopen=await finishProbe(host+'-reopen');anchored(reopen.final,host+'-reopen');
   assert.equal(await js("document.querySelectorAll('[role=dialog]').length"),1,'Repeated opening left multiple live dialogs');
   assert.equal(await js("document.querySelectorAll('[data-surface-exit=modal]').length"),0,'Old exit ghost remained');
   const landscapeWidth=reopen.final.panel.width;
   win.setContentSize(440,956);await js("document.querySelector('main').style.cssText+=';--mv-safe-left:0px;--mv-safe-right:0px;--mv-safe-top:47px;--mv-safe-bottom:34px';window.dispatchEvent(new Event('minivoice-insets'))");await wait(500);
   await arm();await wait(360);const portrait=await finishProbe(host+'-portrait-rotation');anchored(portrait.final,host+'-portrait-rotation');assert.ok(Math.abs(portrait.final.panel.width-landscapeWidth)<.6,'Rotation changed portrait/landscape width');assert.equal(portrait.styleWrites,0,'Settled portrait repeats geometry writes');
   // Return to landscape while mounted: only actual viewport/inset changes update geometry.
   win.setContentSize(956,440);await js("document.querySelector('main').style.cssText+=';--mv-safe-left:59px;--mv-safe-right:0px;--mv-safe-top:0px;--mv-safe-bottom:21px';window.dispatchEvent(new Event('minivoice-insets'))");await wait(500);
   await arm();await wait(360);const rotated=await finishProbe(host+'-landscape-rotation');anchored(rotated.final,host+'-landscape-rotation');assert.equal(rotated.styleWrites,0,'Settled landscape repeats geometry writes');
   await js("document.querySelector('[aria-label=关闭弹窗]').click();document.querySelector('[aria-label=播放模式]').click()");await wait(80);
   assert.equal(await js("document.querySelector('.mv-modal-shade')?.dataset.modalVariant||''"),'','Other modal inherited anchor variant');
   assert.equal(await js("document.querySelector('.mv-modal').style.height"),'','Other modal inherited explicit height');
  }
  fs.writeFileSync(path.join(output,'work.json'),JSON.stringify(results,null,2));
  console.log('PASS settings touch motion matrix: stable layout/visual anchor, corners cover search and settings, differential writes, themes/cutouts/reduced motion/reopen/rotation/modal isolation');
 }
 clearTimeout(deadline);win.destroy();win=null;app.exit(0);
 }catch(error){console.error(error);fs.writeFileSync(path.join(output,'failed.json'),JSON.stringify({error:error.stack,results},null,2));if(win)fs.writeFileSync(path.join(output,'failure.png'),(await win.webContents.capturePage()).toPNG());clearTimeout(deadline);win?.destroy();app.exit(1);}});
