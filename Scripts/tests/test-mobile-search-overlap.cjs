const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{try{
 for(const host of ['ios','android']){
 const win=new BrowserWindow({show:false,width:1000,height:460,webPreferences:{backgroundThrottling:false}}),js=s=>win.webContents.executeJavaScript(s,true);
 await win.loadURL(`http://127.0.0.1:5196/tests/wall-mobile.html?host=${host}`);await wait(1200);
 await js("document.documentElement.style.setProperty('--mv-safe-bottom','21px');document.documentElement.style.setProperty('--mv-safe-left','59px');document.querySelector('.mv-button[aria-label=搜索音乐]').click()");await wait(550);
 const probe=()=>js("(()=>{const b=document.querySelector('.mv-toolbar>[aria-label=打开侧边栏]'),s=document.querySelector('.mv-search-control'),r=b.getBoundingClientRect(),q=s.getBoundingClientRect(),c=getComputedStyle(b);return {overlap:q.left<r.right&&q.right>r.left,visible:c.visibility==='visible'&&Number(c.opacity)>0,inert:b.inert,top:r.top,search:q.toJSON(),opened:s.dataset.open}})()");
 let result=await probe();assert.equal(result.overlap,false);assert.equal(result.visible,true,host+' wide sidebar disappeared');assert.equal(result.inert,false);
 if(host==='ios')assert.equal(result.top,35,'Balanced iOS landscape top gap');
 // Narrow the toolbar to reproduce coverage without hiding it through a breakpoint.
 await js("document.querySelector('.mv-toolbar').style.right='calc(100% - 300px)'");await wait(550);result=await probe();assert.equal(result.overlap,true);assert.equal(result.visible,false);assert.equal(result.inert,true);
 await js("document.querySelector('[aria-label=收起搜索]').click()");await wait(550);result=await probe();assert.equal(result.visible,true);assert.equal(result.inert,false);
 await js("document.querySelector('[aria-label=打开侧边栏]').click()");await wait(300);
 if(host==='ios')assert.equal(await js("(()=>{const r=document.querySelector('.mv-drawer').getBoundingClientRect();return Math.abs(r.top-(innerHeight-r.bottom))<1})()"),true,'Drawer vertical margins differ');
 win.destroy();console.log('PASS '+host+' actual search overlap, restore and landscape geometry');
 }
 app.exit(0);
 }catch(e){console.error(e);app.exit(1);}});
