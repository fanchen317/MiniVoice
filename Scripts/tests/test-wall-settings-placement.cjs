const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const output=path.resolve('.build/reports/ui/wall-settings');fs.mkdirSync(output,{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/wall-settings-profile-')));
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5298';
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{let win;const results=[];try{
 for(const host of ['ios','android']){
  win=new BrowserWindow({show:false,width:440,height:956,useContentSize:true,webPreferences:{backgroundThrottling:false}});
  const js=source=>win.webContents.executeJavaScript(source,true);
  await win.loadURL(base+'/tests/wall-mobile.html?host='+host);
  for(let i=0;i<70;i++){if(await js("document.querySelector('main')?.dataset.ready==='true'"))break;await pause(80);}
  await js("document.documentElement.classList.add('reduce-motion');document.querySelector('[aria-label=音乐墙设置]').click()");await pause(650);
  const read=()=>js(`(()=>{const layer=document.querySelector('.mv-modal-shade'),panel=layer.querySelector('.mv-modal'),button=document.querySelector('[aria-label=音乐墙设置]'),r=panel.getBoundingClientRect(),b=button.getBoundingClientRect(),search=document.querySelector('.mv-search-control').getBoundingClientRect(),s=getComputedStyle(layer);return {width:r.width,height:r.height,top:r.top,searchTop:search.top,right:r.right,bottom:r.bottom,buttonRight:b.right,buttonBottom:b.bottom,maxHeight:parseFloat(getComputedStyle(panel).maxHeight),oldBudget:(layer.clientHeight-parseFloat(s.paddingTop)-parseFloat(s.paddingBottom))*.85,visible:r.top>=Math.max(0,parseFloat(s.paddingTop)-12)-1,scroll:panel.querySelector('.mv-modal-content').scrollHeight>panel.querySelector('.mv-modal-content').clientHeight}})()`);
  const portrait=await read();results.push({host,portrait});assert.ok(Math.abs(portrait.right-portrait.buttonRight)<1&&Math.abs(portrait.bottom-portrait.buttonBottom)<1);
  for(const side of ['left','right']){
   win.setContentSize(956,440);await js(`document.querySelector('main').style.cssText+=';--mv-safe-${side}:59px;--mv-safe-${side==='left'?'right':'left'}:0px;--mv-safe-bottom:21px';window.dispatchEvent(new Event('minivoice-insets'))`);await pause(650);
   const landscape=await read();results.push({host,side,portrait,landscape});assert.equal(landscape.width,portrait.width);assert.ok(Math.abs(landscape.right-landscape.buttonRight)<1&&Math.abs(landscape.bottom-landscape.buttonBottom)<1);assert.ok(Math.abs(landscape.top-landscape.searchTop)<1&&Math.abs(landscape.height-(landscape.buttonBottom-landscape.searchTop))<1&&landscape.visible);
   fs.writeFileSync(path.join(output,host+'-'+side+'.png'),(await win.webContents.capturePage()).toPNG());
  }
  await js("document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}))");await pause(70);assert.equal(await js("!!document.querySelector('.mv-modal-shade')"),false);
  await js("document.querySelector('[aria-label=音乐墙设置]').click()");await pause(70);await js("document.querySelector('[aria-label=关闭弹窗]').click();document.querySelector('[aria-label=音乐墙设置]').click()");await pause(650);assert.ok((await read()).visible);
  await js("document.querySelector('[aria-label=关闭弹窗]').click();document.querySelector('[aria-label=播放模式]').click()");await pause(100);assert.equal(await js("document.querySelector('.mv-modal-shade')?.dataset.modalVariant||''"),'');
  win.destroy();win=null;
 }
 fs.writeFileSync(path.join(output,'work.json'),JSON.stringify(results,null,2));console.log('PASS iOS/Android portrait-landscape fixed width, both cutouts, actual anchor, search-to-settings height, rotation while open, Escape and reopen');app.exit(0);
 }catch(e){console.error(e);fs.writeFileSync(path.join(output,'failed.json'),JSON.stringify({error:e.message,results},null,2));win?.destroy();app.exit(1);}});
