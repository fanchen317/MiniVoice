const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{try{
 const w=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false}});
 const js=s=>w.webContents.executeJavaScript(s,true);
 for(const host of ['android','ios']){
  await w.loadURL('http://127.0.0.1:5194/tests/wall-mobile.html?host='+host);await pause(900);
  await js(`window.pressNode=document.querySelector('.mv-wall-card');window.before=pressNode.getBoundingClientRect().toJSON();window.touch=(type,x=100,multi=false)=>{const e=new Event(type,{bubbles:true,cancelable:true});Object.defineProperty(e,'touches',{value:/end|cancel/.test(type)?[]:[{identifier:1,clientX:x,clientY:150},...(multi?[{identifier:2,clientX:200,clientY:150}]:[])]});Object.defineProperty(e,'changedTouches',{value:[]});pressNode.dispatchEvent(e)};touch('touchstart')`);
  await pause(250);
  const sample=await js(`(()=>{const r=pressNode.getBoundingClientRect(),s=pressNode.querySelector('.mv-wall-press-surface'),v=s.getBoundingClientRect();return {scale:new DOMMatrixReadOnly(getComputedStyle(s).transform).a,drift:Math.max(Math.abs(r.x-before.x),Math.abs(r.y-before.y)),centre:Math.max(Math.abs(v.left+v.right-r.left-r.right),Math.abs(v.top+v.bottom-r.top-r.bottom))/2,outline:getComputedStyle(s).outlineStyle}})()`);
  assert.ok(Math.abs(sample.scale-.96)<.001,JSON.stringify(sample));assert.ok(sample.drift<.1&&sample.centre<.2,JSON.stringify(sample));assert.equal(sample.outline,'solid');
  for(const action of ["touch('touchmove',120)","touch('touchstart');touch('touchcancel')","touch('touchstart',100,true)"]){await js(action);assert.equal(await js("pressNode.classList.contains('is-touch-pressed')"),false)}
  await js("touch('touchcancel');window.wasPlaying=wallFixture.state.playing;pressNode.click()");await pause(100);assert.ok(await js("!!document.querySelector('.mv-wall-focused')"),'Single click focus lost');
  await js(host==='ios'?"pressNode.dispatchEvent(new MouseEvent('click',{bubbles:true,detail:1,clientX:0,clientY:0}))":"pressNode.click()");await pause(600);
  assert.notEqual(await js('wallFixture.state.playing'),await js('wasPlaying'),'Double click playback lost');
  assert.equal(await js("getComputedStyle(document.querySelector('.mv-wall-focused'),'::after').display"),'none');
  await js("window.pressNode=document.querySelector('.mv-wall-focused');window.before=pressNode.getBoundingClientRect().toJSON();touch('touchstart')");await pause(200);
  assert.ok(await js("(()=>{const r=pressNode.getBoundingClientRect(),v=pressNode.querySelector('.mv-wall-press-surface').getBoundingClientRect();return Math.abs(v.width/r.width-.96)<.001&&Math.abs(v.height/r.height-.96)<.001&&Math.abs(v.left+v.right-r.left-r.right)<.3&&Math.abs(v.top+v.bottom-r.top-r.bottom)<.3})()"),'Focused card press differs from ordinary card');await js("touch('touchcancel')");

  require('node:fs').writeFileSync('.build/reports/ui/wall-press-layer-'+host+'.png',(await w.webContents.capturePage()).toPNG());
  await js("document.documentElement.classList.add('reduce-motion');touch('touchstart')");await pause(30);assert.equal(await js("new DOMMatrixReadOnly(getComputedStyle(pressNode.querySelector('.mv-wall-press-surface')).transform).a"),1);
 }
 console.log('PASS Android/iOS centred visual press, stable hit box, cancel, single focus, double playback and shade stacking');app.exit(0);
}catch(e){console.error(e);app.exit(1)}});
