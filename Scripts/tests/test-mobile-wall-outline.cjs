const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false,partition:'outline-'+Date.now()}});
 const js=s=>win.webContents.executeJavaScript(s,true);
 for(const host of ['ios','android']){
  if(win.webContents.getURL().startsWith('http'))await js('localStorage.clear();sessionStorage.clear()');
  await win.loadURL('http://127.0.0.1:5194/tests/wall-mobile.html?host='+host);await wait(900);
  await js(`document.querySelector('.mv-wall-card[data-wall-id="1"]').click()`);await wait(750);
  assert.ok(await js(`(()=>{const n=document.querySelector('.mv-wall-focused.is-preview .mv-wall-focus-outline');if(!n)return false;const s=getComputedStyle(n);return s.display!=='none'&&parseFloat(s.borderTopWidth)>0&&s.borderTopColor===s.borderBottomColor&&s.borderLeftColor===s.borderRightColor&&+s.zIndex>1&&!document.querySelector('.is-touch-pressed')})()`),host+' preview must retain a complete contour after release');
  await js(`document.querySelector('[aria-label="展开播放器"]').click()`);await wait(700);
  assert.equal(await js(`getComputedStyle(document.querySelector('.mv-wall-focus-outline')).display`),'none',host+' fullscreen has no contour');
  console.log('PASS '+host+' complete preview outline after release; fullscreen hides contour');
 }
 win.destroy();app.exit(0);
}catch(e){console.error(e);win?.destroy();app.exit(1)}});
