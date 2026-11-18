const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{createRequire}=require('node:module');

function fixture(){
 const mainFile=path.resolve(__dirname,'../electron/main.cjs'),actualRequire=createRequire(mainFile),app={requestSingleInstanceLock:()=>true,quit(){},on(){},whenReady:()=>new Promise(()=>{}),getPath:()=>'/isolated'};
 const disk={writeFile:async()=>{},rename:async()=>{}},main={require:id=>id==='electron'?{app,protocol:{registerSchemesAsPrivileged(){}}}:id==='node:fs/promises'?disk:actualRequire(id),__dirname:path.dirname(mainFile),process:{argv:[],execPath:'MiniVoice.exe'},console,setTimeout,clearTimeout,setImmediate};
 vm.runInNewContext(fs.readFileSync(mainFile,'utf8')+'\nglobalThis.__fixture={request,reset:()=>{state.songs=[{id:"a"}];state.current="a";state.queue=["a"];state.position=10000;playing=true;}};',main);
 main.__fixture.reset();const handlers={},bridges={};let audio;
 class FakeAudio{constructor(){audio=this;this.currentTime=10;this.duration=60;this.paused=false;this.readyState=1;this.events={};}addEventListener(name,callback){(this.events[name]??=[]).push(callback);}emit(name){for(const callback of this.events[name]||[])callback();}pause(){this.paused=true;}async play(){this.paused=false;}load(){}removeAttribute(){}}
 const ipcRenderer={invoke:(name,payload)=>name==='request'?main.__fixture.request(payload):Promise.resolve(),on:(name,handler)=>{handlers[name]=handler;},send(){}};
 const preload=path.resolve(__dirname,'../electron/preload.cjs');vm.runInNewContext(fs.readFileSync(preload,'utf8'),{require:id=>{if(id==='electron')return {ipcRenderer,contextBridge:{exposeInMainWorld:(name,value)=>bridges[name]=value}};throw Error(id);},Audio:FakeAudio,navigator:{},location:{href:'https://test/?surface=1'},URL,console,setTimeout,clearTimeout});
 return {audio,bridge:bridges.miniVoiceWindows,handlers};
}

test('explicit subsecond seeks and replay take effect without rewinding ordinary snapshots',async()=>{
 const {audio,bridge,handlers}=fixture();
 handlers.audio(null,{audio:{id:'a',position:10000,playing:true}});audio.emit('loadedmetadata');audio.currentTime=10;
 await bridge.request({version:1,kind:'seek',position:10500});assert.equal(audio.currentTime,10.5);
 audio.currentTime=10.8;await bridge.request({version:1,kind:'toggle'});assert.equal(audio.currentTime,10.8,'ordinary stale position does not rewind audio');
 audio.currentTime=.4;await bridge.request({version:1,kind:'play',id:'a'});assert.equal(audio.currentTime,0,'replaying the same song restarts it');
});

test('a seek issued before metadata replaces the pending restoration point',async()=>{
 const {audio,bridge,handlers}=fixture();handlers.audio(null,{audio:{id:'a',position:10000,playing:true}});audio.emit('loadedmetadata');
 audio.readyState=0;await bridge.request({version:1,kind:'seek',position:10250});assert.equal(audio.currentTime,10);
 audio.readyState=1;audio.emit('loadedmetadata');assert.equal(audio.currentTime,10.25);
});
