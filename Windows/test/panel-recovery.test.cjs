const {test}=require('node:test'),assert=require('node:assert/strict'),Module=require('node:module'),os=require('node:os'),path=require('node:path');
const {desktopHost}=require('../electron/desktop.cjs');

function fixture(fail,{delayedClosed=false}={}){
 const windows=[],closed=[],state={songs:[],folders:[],favorites:[],recent:[],playlists:[],position:0,mode:1,preferences:{wordTimingCache:'disabled'}};
 class Window{
  static getAllWindows(){return windows.filter(w=>!w.destroyed);}
  constructor(){this.handlers={};this.webContents={on(){},setWindowOpenHandler(){},send(){}};this.ignore=[];windows.push(this);}
  setMenu(){}setMenuBarVisibility(){}on(name,fn){this.handlers[name]=fn;}isDestroyed(){return Boolean(this.destroyed);}getBounds(){return {x:0,y:0,width:720,height:160};}
  setPosition(){}setIgnoreMouseEvents(value){this.ignore.push(value);}show(){}focus(){}isMinimized(){return false;}
  async loadFile(file,{query}){if(fail(query))throw Error('synthetic load failure');}
  destroy(){this.destroyed=true;if(delayedClosed)closed.push(()=>this.handlers.closed?.());else this.handlers.closed?.();}close(){this.destroy();}
 }
 const electron={screen:{getAllDisplays:()=>[{workArea:{x:0,y:0,width:1200,height:800}}]}};
 const original=Module._load;Module._load=function(id,...args){return id==='electron'?electron:original.call(this,id,...args);};
 const host=desktopHost({app:{getPath:()=>path.join(os.tmpdir(),'minivoice-panel-test-'+process.pid),once(){}},BrowserWindow:Window,getState:()=>state,getWindow:()=>null,getPlaying:()=>false,save:async()=>{},lyrics:async()=>'',coreRequest:async()=>[],request:async()=>true});
 return {host,state,windows,flushClosed:()=>{for(const finish of closed.splice(0))finish();},restore:()=>{Module._load=original;}};
}

test('failed settings window is discarded so the next click can retry',async t=>{
 let attempts=0;const f=fixture(query=>query.panel==='settings'&&++attempts===1);t.after(f.restore);
 await assert.rejects(f.host.command('openSettings'),/synthetic load failure/);assert.equal(f.windows[0].destroyed,true);
 assert.equal(await f.host.command('openSettings'),true);assert.equal(attempts,2);assert.equal(f.windows.length,2);
});
test('a late closed event from the failed window does not remove its replacement',async t=>{
 let attempts=0;const f=fixture(query=>query.panel==='settings'&&++attempts===1,{delayedClosed:true});t.after(f.restore);
 await assert.rejects(f.host.command('openSettings'),/synthetic load failure/);
 await f.host.command('openSettings');f.flushClosed();await f.host.command('openSettings');
 assert.equal(attempts,2);assert.equal(f.windows.length,2);assert.equal(f.windows[1].destroyed,undefined);
});
test('failure to restore desktop lyrics does not abort app startup and remains retryable',async t=>{
 let shouldFail=true;const f=fixture(query=>query.surface==='desktopLyrics'&&shouldFail);t.after(f.restore);f.state.desktopLyrics=true;
 await assert.doesNotReject(f.host.restore());assert.equal(f.state.desktopLyrics,false);assert.equal(f.windows[0].destroyed,true);
 shouldFail=false;await f.host.command('desktopLyrics');assert.equal(f.state.desktopLyrics,true);assert.equal(f.windows.length,2);
});
test('failed desktop lyrics unlock window restores clickability',async t=>{
 let failUnlock=true;const f=fixture(query=>query.surface==='desktopLyricsUnlock'&&failUnlock);t.after(f.restore);
 await f.host.command('desktopLyrics');const lyrics=f.windows[0];
 await assert.rejects(f.host.command('desktopLyricsConfig',{locked:true}),/synthetic load failure/);
 assert.equal(f.state.desktopLyricsLocked,false);assert.deepEqual(lyrics.ignore,[true,false]);assert.equal(f.windows[1].destroyed,true);
 failUnlock=false;await f.host.command('desktopLyricsConfig',{locked:true});assert.equal(f.state.desktopLyricsLocked,true);assert.equal(f.windows.length,3);
});
