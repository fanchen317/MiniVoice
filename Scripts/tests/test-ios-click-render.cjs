const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{try{
 const win=new BrowserWindow({show:false,width:440,height:956,webPreferences:{backgroundThrottling:false}});
 win.webContents.on("console-message",(_e,_l,m)=>console.log(m));
 const js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL('http://127.0.0.1:5194/tests/wall-mobile.html?host=ios');await pause(1200);
 for(let i=0;i<5;i++){
  await js(`(()=>{const wall=document.querySelector('.mv-cover-wall');window.clickScroll={x:wall.scrollLeft,y:wall.scrollTop};const cards=[...document.querySelectorAll('.mv-wall-card:not(.is-focus-underlay)')].filter(n=>{const r=n.getBoundingClientRect();return r.right>30&&r.bottom>100&&r.left<innerWidth-30&&r.top<innerHeight-100});if(!cards.length)throw Error('No visible card');cards[${i}%cards.length].click()})()`);
  for(let frame=0;frame<12;frame++){await pause(35);assert.equal(await js(`(()=>{const w=document.querySelector('.mv-cover-wall');return Math.abs(w.scrollLeft-clickScroll.x)<1&&Math.abs(w.scrollTop-clickScroll.y)<1})()`),true,'Click changed native scroll position');assert.ok(await js(`(()=>{const w=document.querySelector('.mv-cover-wall'),r=w.getBoundingClientRect();return [document.elementFromPoint(r.width/2,r.height/2),document.elementFromPoint(r.width/3,r.height/3)].some(n=>n?.closest('.mv-wall-card,.mv-wall-focused'))})()`),'Wall has no painted DOM coverage');}
  await pause(180);assert.notEqual(await js("document.querySelector('.mv-cover-wall').style.overflow"),'hidden','Native scrolling remains locked after focus');
 }
 console.log('PASS iOS native click: stable scroll position and intermediate DOM coverage across five selections (Electron, not device GPU)');app.exit(0);
}catch(e){console.error(e);app.exit(1)}});
