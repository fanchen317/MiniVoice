const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pause=ms=>new Promise(r=>setTimeout(r,ms));const out=path.resolve('.build/reports/ui/duo-trailing-column');fs.mkdirSync(out,{recursive:true});
app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/duo-trailing-profile-')));
app.whenReady().then(async()=>{let win;const rows=[];try{
 win=new BrowserWindow({show:false,width:951,height:669,useContentSize:true,webPreferences:{backgroundThrottling:false}});const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5310/tests/wall-mobile.html?host=ios');for(let i=0;i<80;i++){if(await js("document.querySelector('main')?.dataset.ready==='true'"))break;await pause(100);}
 for(const [name,w,h,occlusion] of [['upper-right',951,669,{x:867,y:0,width:84,height:124}],['lower-right',951,669,{x:867,y:545,width:84,height:124}],['portrait',669,951,{x:525,y:0,width:144,height:82}]]){
  win.setContentSize(w,h);await js(`window.miniVoiceOcclusions=[${JSON.stringify(occlusion)}];window.miniVoiceFold={duo:true,top:0,bottom:0};dispatchEvent(new Event('minivoice-insets'))`);await pause(700);
  await js("document.querySelector('.wp-dock-meter').click()");await pause(500);
  const r=await js(`(()=>{const box=s=>{const r=document.querySelector(s).getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom}};return {search:box('.mv-search-control'),settings:box('[data-wall-control=settings]'),dock:box('.mv-wall-dock')}})()`);
  assert.ok(Math.abs(r.search.x-r.settings.x)<1&&Math.abs(r.search.right-r.settings.right)<1,'trailing controls share exact axis');
  assert.ok(Math.abs(r.dock.x+r.dock.width/2-(14+r.search.right)/2)<1,'expanded dock centers in the main content region');
  for(const k of ['search','settings']){const b=r[k],o=occlusion;assert.ok(!(b.x<o.x+o.width&&b.right>o.x&&b.y<o.y+o.height&&b.bottom>o.y),'control avoids actual system occlusion');}
  if(name==='upper-right')assert.ok(Math.abs(h-r.settings.bottom-14)<1,'alignment preserves bottom gap');
  await js("document.querySelector('[aria-label=音乐墙设置]').click()");await pause(500);const p=await js("(()=>{const r=document.querySelector('.mv-modal').getBoundingClientRect(),l=document.querySelector('.mv-modal-shade').getBoundingClientRect();return {right:r.right,bottom:r.bottom,layerRight:l.right}})()");assert.ok(Math.abs(p.right-r.settings.right)<1&&Math.abs(p.bottom-r.settings.bottom)<1,'settings popup covers exact settings anchor');assert.ok(p.layerRight<=r.search.right+1,'popup layer excludes system status column');await js("document.querySelector('[aria-label=关闭弹窗]').click()");await pause(300);
  rows.push({name,...r,popup:p});fs.writeFileSync(path.join(out,name+'.png'),(await win.webContents.capturePage()).toPNG());
 }
 fs.writeFileSync(path.join(out,'geometry.json'),JSON.stringify(rows,null,2));console.log('PASS aligned search/settings axis, both cutout directions, portrait, centered expanded dock and bottom gap');win.destroy();app.exit(0);
}catch(e){console.error(e);win?.destroy();app.exit(1);}});
