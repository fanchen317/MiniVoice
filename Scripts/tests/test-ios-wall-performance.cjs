// Chromium DOM/per-frame-work evidence; this does not measure iOS GPU FPS.
const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});
 const js=source=>win.webContents.executeJavaScript(source,true);
 await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5190')+'/tests/wall-mobile.html?host=ios');await wait(900);
 assert.equal(await js("document.querySelector('.mv-cover-wall').dataset.wallRenderer"),'projected-single-surface');
 await js("document.querySelector('.mv-wall-card[data-wall-id=\"0\"]').click()");await wait(800);
 await js(`window.repeatedWallVariables=0;window.wordProgressWrites=0;window.originalSetProperty=CSSStyleDeclaration.prototype.setProperty;
  CSSStyleDeclaration.prototype.setProperty=function(key,value,...rest){if(key.startsWith('--wall-')&&this.getPropertyValue(key)===String(value))repeatedWallVariables++;if(key==='--word-progress')wordProgressWrites++;return originalSetProperty.call(this,key,value,...rest)};
  wallFixture.state.playing=true;`);await wait(500);
 for(let i=0;i<12;i++){await js("document.querySelector('.mv-cover-wall').dispatchEvent(new WheelEvent('wheel',{deltaX:8,deltaY:3,bubbles:true,cancelable:true}))");await wait(24);}
 await wait(300);
 const result=await js("({repeatedWallVariables,wordProgressWrites,lyrics:document.querySelectorAll('.wp-line').length,sweep:!!document.querySelector('.lyric-content.sweep-surface')})");
 assert.equal(result.repeatedWallVariables,0,'Pan rewrote unchanged layout/typography variables');assert.equal(result.wordProgressWrites,0,'Sweep invalidated individual word styles');assert.ok(result.lyrics>0&&result.sweep,'Timed lyrics lost their rendered sweep');
 for(const [position,expected] of [[2000,'第 1 行'],[42000,'第 11 行'],[6000,'第 2 行']]){
  await js(`wallFixture.state.playing=false;wallFixture.state.position=${position}`);await wait(600);
  assert.ok(await js(`document.querySelector('.wp-line[data-active=true]')?.textContent.includes(${JSON.stringify(expected)})`),'Lyric seek selected the wrong row at '+position);
 }
 await js("document.documentElement.classList.add('reduce-motion');document.querySelector('.wp-expand-toggle').click()");await wait(500);
 const bounds=await js("(()=>{const wall=document.querySelector('.mv-cover-wall').getBoundingClientRect(),focus=document.querySelector('.mv-wall-focused').getBoundingClientRect();return {width:Math.abs(wall.width-focus.width),height:Math.abs(wall.height-focus.height),expanded:document.querySelector('.wp-player').classList.contains('is-expanded')}})()");
 assert.ok(bounds.expanded&&bounds.width<2&&bounds.height<2,'Reduced-motion expansion did not reach real final bounds');
 fs.mkdirSync('.build/reports/ios/wall-performance',{recursive:true});fs.writeFileSync('.build/reports/ios/wall-performance/work.json',JSON.stringify({result,bounds},null,2));
 fs.writeFileSync('.build/reports/ios/wall-performance/expanded.png',(await win.webContents.capturePage()).toPNG());
 console.log('PASS projected iOS wall avoids redundant variable/word writes, preserves lyric seeking and reduced-motion final layout '+JSON.stringify(result));win.destroy();app.exit(0);
}catch(error){console.error(error);win?.destroy();app.exit(1);}});
