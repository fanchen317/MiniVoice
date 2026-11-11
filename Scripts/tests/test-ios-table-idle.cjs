const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pause=ms=>new Promise(r=>setTimeout(r,ms)),out=path.resolve('.build/reports/ui/table-idle');fs.mkdirSync(out,{recursive:true});app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/table-idle-profile-')));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:669,height:951,useContentSize:true,webPreferences:{backgroundThrottling:false}});const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5310/tests/wall-mobile.html?host=ios');for(let i=0;i<80;i++){if(await js("document.querySelector('main')?.dataset.ready==='true'"))break;await pause(100);}
 await js("window.miniVoiceFold={duo:true,top:455.5,bottom:495.5};window.wallFixture.state.current=null;dispatchEvent(new Event('minivoice-insets'))");await pause(1300);
 for(const theme of ['light','dark']){
  await js("document.querySelector('[aria-label=打开侧边栏]').click()");await pause(200);await js("document.querySelector('[aria-label=设置]').click()");await pause(200);await js(`(()=>{const b=[...document.querySelectorAll('button')].find(e=>e.textContent.trim()==='${theme==='light'?'浅色模式':'深色模式'}');b.click()})()`);await pause(200);await js("document.querySelector('[aria-label=关闭弹窗]').click()");await pause(300);assert.equal(await js("document.querySelector('main').dataset.theme"),theme);
  const ink=await js("getComputedStyle(document.querySelector('.mv-table-idle')).color");assert.equal(ink,theme==='light'?'rgb(25, 54, 47)':'rgb(243, 251, 248)','clock and copy use resolved theme ink');
  assert.equal(await js("document.querySelectorAll('[data-mv-component=table-idle]').length"),1);
  assert.ok(await js("/^\\d{2}:\\d{2}$/.test(document.querySelector('.mv-idle-clock').textContent)"));
  assert.equal(await js("document.querySelectorAll('.mv-table-idle button,.mv-table-idle input').length"),0,'fixed page has no customization entry');
  const bounds=await js("(()=>{const i=document.querySelector('.mv-table-idle').getBoundingClientRect(),c=document.querySelector('.mv-idle-content').getBoundingClientRect();return {bottom:i.bottom,contentBottom:c.bottom,top:c.top}})()");assert.ok(Math.abs(bounds.bottom-475.5)<1&&bounds.contentBottom<=455.5&&bounds.top>=0,'idle content respects upper fold margin');
  fs.writeFileSync(path.join(out,theme+'.png'),(await win.webContents.capturePage()).toPNG());
 }
 win.webContents.debugger.attach('1.3');
 await win.webContents.debugger.sendCommand('Emulation.setEmulatedMedia',{features:[{name:'prefers-color-scheme',value:'dark'}]});
 await js("document.querySelector('[aria-label=打开侧边栏]').click()");await pause(200);await js("document.querySelector('[aria-label=设置]').click()");await pause(200);await js("[...document.querySelectorAll('button')].find(e=>e.textContent.trim()==='跟随系统').click();document.querySelector('[aria-label=关闭弹窗]').click()");await pause(400);assert.equal(await js("document.querySelector('main').dataset.theme"),'dark');
 await win.webContents.debugger.sendCommand('Emulation.setEmulatedMedia',{features:[{name:'prefers-color-scheme',value:'light'}]});await pause(400);assert.equal(await js("document.querySelector('main').dataset.theme"),'light','system theme change updates idle without remount');win.webContents.debugger.detach();
 await js("wallFixture.state.current='0';wallFixture.state.playing=true");await pause(1300);assert.equal(await js("!!document.querySelector('.mv-table-idle')"),false,'selecting track hands off to player');assert.ok(await js("!!document.querySelector('.mv-table-player .wp-player')"));
 await js("window.miniVoiceFold={duo:true,top:0,bottom:0};wallFixture.state.current=null;dispatchEvent(new Event('minivoice-insets'))");await pause(1300);assert.equal(await js("!!document.querySelector('.mv-table-idle')"),false,'flat posture has no idle page');
 await js("window.miniVoiceFold={duo:true,top:455.5,bottom:495.5};wallFixture.state.songs=[];dispatchEvent(new Event('minivoice-insets'))");await pause(1300);assert.ok(await js("!!document.querySelector('.mv-table-idle')"),'empty library still has a complete page');
 console.log('PASS fixed table idle page, clock, light/dark, fold boundary, no configuration, select/play handoff, flat restoration and empty library');win.destroy();app.exit(0);
}catch(e){console.error(e);win?.destroy();app.exit(1);}});
