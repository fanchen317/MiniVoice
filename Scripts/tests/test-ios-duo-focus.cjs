const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const out=path.resolve('.build/reports/ui/duo-focus');fs.mkdirSync(out,{recursive:true});app.setPath('userData',fs.mkdtempSync(path.resolve('.build/work/duo-focus-')));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:669,height:951,useContentSize:true,webPreferences:{backgroundThrottling:false}});const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5310/tests/wall-mobile.html?host=ios');await pause(1200);
 await js("window.miniVoiceOcclusions=[{x:525,y:0,width:144,height:160}];window.miniVoiceFold={duo:true,top:0,bottom:0};dispatchEvent(new Event('minivoice-insets'));document.querySelector('.mv-wall-card').click()");await pause(1100);
 const read=`(()=>{const f=document.querySelector('.mv-wall-focused').getBoundingClientRect(),m=document.querySelector('.mv-menu-control')?.getBoundingClientRect(),s=document.querySelector('.mv-search-control').getBoundingClientRect();return {x:f.x+f.width/2,width:f.width,target:(14+s.right)/2}})()`;
 const portrait=await js(read);assert.ok(Math.abs(portrait.x-portrait.target)<1,JSON.stringify(portrait));
 fs.writeFileSync(path.join(out,'portrait.png'),(await win.webContents.capturePage()).toPNG());
 win.setContentSize(1100,800);await js("window.miniVoiceOcclusions=[];dispatchEvent(new Event('minivoice-insets'))");await pause(1000);
 const results=[];
 for(const book of [true,false]){
  await js(`window.focusFrames=[];window.miniVoiceFold={duo:true,top:0,bottom:0,left:${book?535:0},right:${book?565:0}};dispatchEvent(new Event('minivoice-insets'));{const start=performance.now();const tick=()=>{const r=document.querySelector('.mv-wall-focused').getBoundingClientRect();focusFrames.push({t:performance.now()-start,x:r.x+r.width/2,width:r.width});if(performance.now()-start<800)requestAnimationFrame(tick)};requestAnimationFrame(tick)};true`);
  await pause(900);const frames=await js('focusFrames'),target=book?(14+535)/2:550;
  assert.ok(Math.abs(frames.at(-1).x-target)<1,JSON.stringify(frames.at(-1)));
  const first=frames[0].x;assert.ok(frames.some(f=>Math.abs(f.x-first)>3&&Math.abs(f.x-target)>3),'has actual intermediate focus positions');
  results.push({book,target,frames});
 }
 fs.writeFileSync(path.join(out,'frames.json'),JSON.stringify({portrait,results},null,2));console.log('PASS localized portrait focus center and bidirectional landscape book focus intermediate frames');win.destroy();app.exit(0);
}catch(e){console.error(e);win?.destroy();app.exit(1);}});
