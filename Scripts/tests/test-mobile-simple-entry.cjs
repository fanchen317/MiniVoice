const {app,BrowserWindow}=require('electron');
const assert=require('node:assert/strict');
let win;const wait=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{try{
win=new BrowserWindow({show:false,width:390,height:844,webPreferences:{backgroundThrottling:false}});
const js=s=>win.webContents.executeJavaScript(s,true);
await win.loadURL((process.env.MINIVOICE_WALL_TEST_URL||'http://127.0.0.1:5217')+'/tests/wall-mobile.html');await wait(600);
await js(`window.wallFixture.state.current=null;document.querySelector('[aria-label="打开侧边栏"]').click();true`);await wait(400);
await js(`document.querySelector('.mv-drawer [aria-label="设置"]').click();true`);await wait(400);
await js(`Array.from(document.querySelectorAll('.mv-mobile-settings button')).find(n=>n.textContent==='简易').click();true`);await wait(700);
assert.equal(await js(`document.querySelector('main').dataset.style`),'simple');
assert.equal(await js(`document.querySelector('.mv-hero h1')?.textContent`),'选择歌曲');
assert.equal(await js(`!!document.querySelector('.mv-scene>.mv-library')`),false);
assert.equal(await js(`document.querySelector('.mv-now strong')?.textContent`),'选择歌曲');
// Restore a persisted catalogue page from an older version: launch must still show the player.
await js(`(()=>{const s=window.wallFixture.workspace();s.pages['音乐库\\n']={catalog:true,lyrics:true};localStorage.setItem('wall-fixture-v2',JSON.stringify(s));})()`);
await win.reload();await wait(1000);
assert.equal(await js(`document.querySelector('main').dataset.style`),'simple');
assert.equal(await js(`!!document.querySelector('.mv-hero')`),true);
assert.equal(await js(`!!document.querySelector('.mv-scene>.mv-library')`),false);
console.log('PASS simple settings entry and persisted catalogue launch show player; empty song title is 选择歌曲');
win.destroy();app.exit(0);
}catch(e){console.error(e);win?.destroy();app.exit(1)}});
