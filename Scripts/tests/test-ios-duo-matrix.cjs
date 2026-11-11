const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pause=ms=>new Promise(r=>setTimeout(r,ms)),out=path.resolve('.build/reports/ui/duo-matrix');fs.mkdirSync(out,{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/duo-matrix-profile-')));
const poses=[['outer-portrait',466,678,{}],['outer-landscape',678,466,{}],['table-portrait',800,1100,{top:535,bottom:565}],['book-landscape',1100,800,{left:535,right:565}],['open-portrait',800,1100,{}],['open-landscape',1100,800,{}]];
app.whenReady().then(async()=>{let win;const rows=[];try{
 win=new BrowserWindow({show:false,width:800,height:1100,useContentSize:true,webPreferences:{backgroundThrottling:false}});const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5311/tests/wall-mobile.html?host=ios');for(let i=0;i<80;i++){if(await js("document.querySelector('main')?.dataset.ready==='true'"))break;await pause(100);}
 const click=async label=>{await js(`(()=>{const b=[...document.querySelectorAll('button')].find(e=>e.getAttribute('aria-label')===${JSON.stringify(label)}&&!e.closest('[hidden]'));if(!b)throw Error('missing '+${JSON.stringify(label)});b.click()})()`);await pause(200);};
 for(const [pose,w,h,fold] of poses){win.setContentSize(w,h);await js(`window.miniVoiceFold=${JSON.stringify({duo:true,top:0,bottom:0,left:0,right:0,...fold})};dispatchEvent(new Event('minivoice-insets'))`);await pause(400);
  for(const [style,label] of [['simple','简易'],['library','音乐库'],['wall','音乐墙']])for(const [theme,labelTheme] of [['light','浅色模式'],['dark','深色模式']]){
   await click('打开侧边栏');await click('设置');await js(`(()=>{const b=[...document.querySelectorAll('.mv-style-picker button')].find(e=>e.textContent.trim()===${JSON.stringify(label)});b.click()})()`);await pause(300);
   await js(`(()=>{const b=[...document.querySelectorAll('button')].find(e=>e.textContent.trim()===${JSON.stringify(labelTheme)});if(!b)throw Error('theme');b.click()})()`);await click('关闭弹窗');await pause(400);if(style==='library'){await js("document.querySelector('.mv-toolbar .mv-back')?.click()");await pause(350);}
   assert.equal(await js("document.querySelector('main').dataset.tableMode"),String(!!fold.top),'table posture applies to every style');
   const bounds=await js(`(()=>{const r=document.querySelector('.mv-scene').getBoundingClientRect();return {top:r.top,bottom:r.bottom,left:r.left,right:r.right}})()`);assert.ok(bounds.top>=(fold.top?(fold.top+fold.bottom)/2:0)&&bounds.bottom<=h&&bounds.left>=0&&bounds.right<=w);
   await click('打开侧边栏');await pause(400);const drawer=await js(`(()=>{const r=document.querySelector('.mv-drawer').getBoundingClientRect();return {top:r.top,bottom:r.bottom}})()`);assert.ok(drawer.top>=(fold.top?(fold.top+fold.bottom)/2:0)&&drawer.bottom<=h,'drawer physical region');
   await click('设置');const modal=await js(`(()=>{const r=document.querySelector('.mv-modal').getBoundingClientRect();return {top:r.top,bottom:r.bottom}})()`);assert.ok(modal.top>=(fold.top?(fold.top+fold.bottom)/2:0)&&modal.bottom<=h,'modal physical region');await click('关闭弹窗');
   if(pose==='book-landscape'&&style==='library'){const panes=await js("(()=>{const l=document.querySelector('.mv-library').getBoundingClientRect(),p=document.querySelector('.mv-player-page').getBoundingClientRect();return {leftEnd:l.right,rightStart:p.left}})()");assert.ok(panes.leftEnd<=535&&panes.rightStart>=565,'book catalog and player avoid fold');}
   fs.writeFileSync(path.join(out,`${pose}-${style}-${theme}.png`),(await win.webContents.capturePage()).toPNG());rows.push({pose,style,theme,bounds,drawer,modal});
  }
 }
 fs.writeFileSync(path.join(out,'matrix.json'),JSON.stringify(rows,null,2));console.log('PASS 36 pose/style/theme cells, active scene, lower drawer and modal');win.destroy();app.exit(0);
}catch(e){console.error(e);fs.writeFileSync(path.join(out,'failed.json'),JSON.stringify({error:e.message,rows},null,2));win?.destroy();app.exit(1);}});
