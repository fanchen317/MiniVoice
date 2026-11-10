// Real shared page, synthetic fixture, isolated preferences; no native music library.
const {app,BrowserWindow,protocol}=require('electron');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
app.setPath('userData',fs.mkdtempSync(path.join(os.tmpdir(),'minivoice-expansion-race-')));
app.on('window-all-closed',()=>{});
protocol.registerSchemesAsPrivileged([{scheme:'minivoice-race-art',privileges:{standard:true,secure:true,supportFetchAPI:true}}]);
const base=process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5190';
const host=process.env.MINIVOICE_WALL_TEST_HOST==='ios'?'ios':'android';
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const check=(value,message)=>{if(!value)throw Error(message);};
let win,repairedArtwork=false;
const js=async source=>{try{return await win.webContents.executeJavaScript(source,true);}catch(error){throw Error('Renderer failed: '+source,{cause:error});}};
async function until(source,message){for(let i=0;i<100;i++){if(await js(source))return;await wait(50);}throw Error(message);}
async function click(selector){check(await js(`(()=>{const node=document.querySelector(${JSON.stringify(selector)});if(!node)return false;node.click();return true;})()`),'Missing '+selector);}
async function openFixture(){
 win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});
 await win.loadURL(base+'/tests/wall-mobile.html'+(host==='ios'?'?host=ios':''));
 await until("document.querySelector('main')?.dataset.ready==='true'&&document.querySelector('.mv-cover-wall')?.clientHeight>100",'Page did not finish hydration');
 await js('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
 await until("!!document.querySelector('.mv-wall-card[data-wall-id=\"0\"]')",'Wall did not mount');
}
async function prepare(){
 await openFixture();
 await js("window.raceDecode=HTMLImageElement.prototype.decode;window.raceReleases=[];HTMLImageElement.prototype.decode=function(){if(!this.classList.contains('mv-wall-focused-art'))return window.raceDecode.call(this);return new Promise(resolve=>window.raceReleases.push(()=>window.raceDecode.call(this).then(resolve)));};document.querySelector('.mv-wall-card[data-wall-id=\"0\"]').click();true");
 await until("window.raceReleases.length>0&&document.querySelector('.mv-wall-focused')?.style.getPropertyValue('--wall-surface-opacity')==='1'",'Focus or delayed decode not ready');
 await click('.mv-wall-focused [aria-label=展开播放器]');await wait(40);
 check(await js("document.querySelector('main').dataset.wallExpanded==='false'"),'Expansion ignored its image preflight');
}
async function release(){await js("HTMLImageElement.prototype.decode=window.raceDecode;window.raceReleases.splice(0).forEach(release=>release());true");}
async function settled(label,{closed=false,focus}={}){
 await wait(750);
 // Chrome returns after both the 360ms card and its 420ms entrance settle.
 await until("document.querySelector('main').dataset.wallChrome==='visible'",label+' did not restore chrome');
 const state=await js("(()=>{const root=document.querySelector('main'),focused=document.querySelector('.mv-wall-focused');return {expanded:root.dataset.wallExpanded,chrome:root.dataset.wallChrome,immersive:wallFixture.state.immersive,focus:focused?.dataset.wallId,error:document.querySelector('.mv-error')?.textContent,workspace:wallFixture.workspace()};})()");
 check(state.expanded==='false'&&state.chrome==='visible'&&!state.immersive,label+' left stale expansion: '+JSON.stringify(state));
 check(!state.error,label+' surfaced an obsolete error: '+state.error);
 if(closed)check(!state.focus,label+' retained a closed focus');
 if(focus)check(state.focus===focus,label+' lost its latest focus: '+JSON.stringify(state));
 console.log('PASS '+host+' '+label);win.destroy();win=null;
}
const timeout=setTimeout(()=>app.exit(2),120000);
app.whenReady().then(async()=>{try{
 protocol.handle('minivoice-race-art',()=>repairedArtwork?new Response('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><path fill="#285a47" d="M0 0h512v512H0z"/></svg>',{headers:{'Content-Type':'image/svg+xml','Cache-Control':'no-store'}}):new Response('Missing cover',{status:404,headers:{'Cache-Control':'no-store'}}));
 await prepare();await js("dispatchEvent(new Event('minivoice-back'));true");await wait(50);await release();await settled('Back cancels delayed expansion',{closed:true});

 await prepare();await click('.mv-wall-focused [aria-label=展开播放器]');await wait(30);await js("dispatchEvent(new Event('minivoice-back'));true");await wait(50);await release();await settled('Repeated expansion requests cannot reopen after Back',{closed:true});

 await prepare();
 const point=await js("(()=>{const r=document.querySelector('.wp-heading h1').getBoundingClientRect();return {x:Math.round(r.x+20),y:Math.round(r.y+r.height/2)};})()");
 const before=await js("document.querySelector('.mv-wall-plane').dataset.camera");
 win.webContents.sendInputEvent({type:'mouseDown',button:'left',clickCount:1,...point});
 for(let i=1;i<=5;i++){win.webContents.sendInputEvent({type:'mouseMove',buttons:['left'],x:point.x+i*12,y:point.y});await wait(20);}
 win.webContents.sendInputEvent({type:'mouseUp',button:'left',clickCount:1,x:point.x+60,y:point.y});await wait(50);
 check(before!==await js("document.querySelector('.mv-wall-plane').dataset.camera"),'Drag fixture did not move the camera');
 await release();await settled('Dragging cancels delayed expansion',{focus:'0'});

 await prepare();await js("wallFixture.state.current='1';true");
 await until("document.querySelector('.mv-wall-focused')?.dataset.wallId==='1'",'New playing song did not acquire focus');
 await release();await settled('Track change cancels previous expansion',{focus:'1'});

 await prepare();const next=await js("(()=>{const card=[...document.querySelectorAll('.mv-wall-card')].find(node=>node.dataset.wallId!=='0');card.click();return card.dataset.wallId;})()");
 await release();await settled('Focus change cancels previous expansion',{focus:next});

 await prepare();win.setSize(844,390);await wait(80);await release();await settled('Rotation cancels delayed expansion',{focus:'0'});

 await prepare();await click('[aria-label=打开侧边栏]');await click('.mv-brand-logo');
 await until("document.querySelector('main').dataset.style==='simple'&&document.querySelector('main').dataset.styleBusy==='false'",'Style switch did not settle');
 await release();await wait(450);
 check(await js("document.querySelector('main').dataset.style==='simple'&&!wallFixture.state.immersive&&!document.querySelector('.mv-error')&&!wallFixture.workspace().pages['音乐库\\n'].wallExpanded"),'Old expansion escaped into the new style');
 console.log('PASS '+host+' Style switch cancels expansion and unmounts its wall');win.destroy();win=null;

 await openFixture();
 await js("window.missingArtErrors=0;document.addEventListener('error',event=>{if(event.target.classList?.contains('mv-wall-focused-art'))window.missingArtErrors++;},true);wallFixture.state.songs=wallFixture.state.songs.map(song=>song.id==='0'?{...song,artwork:'data:image/png;base64,invalid'}:song);true");
 await until("!!document.querySelector('.mv-wall-card[data-wall-id=\"0\"] .mv-art-fallback')",'Missing-cover fixture did not reach the wall');
 await click('.mv-wall-card[data-wall-id="0"]');
 await until("document.querySelector('.mv-wall-focused [data-artwork-state=missing]')?.dataset.artworkReady==='false'",'Failed target must be missing, never decoded-ready');
 await click('.mv-wall-focused [aria-label=展开播放器]');
 await until("document.querySelector('main').dataset.wallExpanded==='true'&&Math.abs(document.querySelector('.mv-wall-focused').getBoundingClientRect().height-innerHeight)<1",'Missing artwork prevented expansion');
 const failedReads=await js('window.missingArtErrors');await wait(450);
 check(await js("!document.querySelector('.mv-wall-focused img')&&document.querySelector('.mv-wall-focused .mv-art-fallback').getBoundingClientRect().height>=innerHeight&&!document.querySelector('.mv-error')&&window.missingArtErrors===1"),'Missing target retried, lost its placeholder or showed an obsolete loading error');
 check(failedReads===1,'Missing artwork request looped before expansion');
 console.log('PASS '+host+' Missing cover expands with a stable placeholder and no retry');win.destroy();win=null;

 await openFixture();
 await js("window.raceDecode=HTMLImageElement.prototype.decode;window.raceReleases=[];HTMLImageElement.prototype.decode=function(){if(!this.classList.contains('mv-wall-focused-art'))return window.raceDecode.call(this);return new Promise(resolve=>window.raceReleases.push(()=>window.raceDecode.call(this).then(resolve)));};wallFixture.state.songs=wallFixture.state.songs.map(song=>song.id==='0'?{...song,artwork:'data:image/png;base64,preview-failed',artworkDetail:song.artwork}:song);true");
 await until("!!document.querySelector('.mv-wall-card[data-wall-id=\"0\"] .mv-art-fallback')",'Failed-preview fixture did not reach the wall');
 await click('.mv-wall-card[data-wall-id="0"]');
 await until("window.raceReleases.length>0&&!!document.querySelector('.mv-wall-focused .mv-art-fallback')",'Final cover was not waiting for decode');
 check(await js("document.querySelector('.mv-wall-focused [data-artwork-state=loading]')?.dataset.artworkReady==='false'"),'A failed preview incorrectly made its pending detail ready');
 await click('.mv-wall-focused [aria-label=展开播放器]');await wait(200);
 check(await js("document.querySelector('main').dataset.wallExpanded==='false'"),'Still-loading detail was treated as missing');
 await release();await until("document.querySelector('main').dataset.wallExpanded==='true'&&document.querySelector('.mv-wall-focused [data-artwork-state=ready]')?.dataset.artworkReady==='true'",'Decoded detail did not complete expansion');
 check(await js("[...document.querySelectorAll('.mv-wall-focused img')].some(image=>image.naturalWidth>0&&getComputedStyle(image).visibility==='visible')&&!document.querySelector('.mv-error')"),'Successful detail did not replace its failed preview');
 console.log('PASS '+host+' Failed preview cannot bypass pending detail decoding');win.destroy();win=null;

 await openFixture();await click('[aria-label=打开侧边栏]');
 for(const style of ['simple','library']){await click('.mv-brand-logo');await until(`document.querySelector('main').dataset.style===${JSON.stringify(style)}&&document.querySelector('main').dataset.styleBusy==='false'`,'Library lifecycle fixture did not settle');}
 await click('[aria-label=关闭侧边栏]');
 await js("window.lifecycleCover=document.querySelector('.mv-cover');wallFixture.state.songs=wallFixture.state.songs.map(song=>song.id==='0'?{...song,artwork:'minivoice-race-art://cover/lifecycle'}:song);true");
 await until("!!document.querySelector('.mv-cover .mv-art-fallback')",'Source A did not fail');
 await wait(450);check(await js("!!document.querySelector('.mv-cover .mv-art-fallback')&&!document.querySelector('.mv-cover img')"),'Unchanged failed source retried on polling');
 await js("wallFixture.state.current='1';true");
 await until("document.querySelector('.mv-cover img')?.naturalWidth>0",'Source B did not replace failed A');
 repairedArtwork=true;await js("wallFixture.state.current='0';true");
 await until("document.querySelector('.mv-cover img')?.getAttribute('src')==='minivoice-race-art://cover/lifecycle'&&document.querySelector('.mv-cover img').naturalWidth===512",'Returning to repaired source A did not retry');
 check(await js("document.querySelector('.mv-cover')===window.lifecycleCover&&!document.querySelector('.mv-error')"),'Lifecycle probe remounted the cover or surfaced an error');
 console.log('PASS '+host+' Artwork A failure, B success, repaired A retries in the same player');win.destroy();win=null;

 // A successful request proves cancellation checks do not make expansion vacuous.
 await prepare();await click('.mv-wall-focused [aria-label=展开播放器]');await release();
 await until("document.querySelector('main').dataset.wallExpanded==='true'&&wallFixture.state.immersive===true",'Latest repeated expansion request never completed');
 await until("Math.abs(document.querySelector('.mv-wall-focused').getBoundingClientRect().height-innerHeight)<1",'Expansion final layout is not full viewport');
 await js("dispatchEvent(new Event('minivoice-back'));true");await settled('Latest expansion completes, then Back collapses it',{focus:'0'});
 clearTimeout(timeout);app.exit(0);
}catch(error){console.error(error.stack);win?.destroy();clearTimeout(timeout);app.exit(1);}});
