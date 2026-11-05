const {contextBridge,ipcRenderer}=require('electron');
const audio=new Audio();let current='',restore=0;
audio.preload='metadata';
audio.addEventListener('loadedmetadata',()=>{if(restore>0){audio.currentTime=Math.min(restore,Number.isFinite(audio.duration)?audio.duration:restore);restore=0;}});
const report=()=>ipcRenderer.invoke('clock',{id:current,position:audio.currentTime*1000,duration:Number.isFinite(audio.duration)?audio.duration*1000:0,playing:!audio.paused}).catch(()=>{});
for(const event of ['timeupdate','pause','play','loadedmetadata'])audio.addEventListener(event,report);
audio.addEventListener('ended',()=>ipcRenderer.invoke('request',{version:1,kind:'skip',delta:1,ended:true}).then(apply).catch(console.error));
audio.addEventListener('error',()=>ipcRenderer.invoke('audio-error','当前音频无法解码，请选择其他歌曲').catch(()=>{}));
async function apply(result){if(result?.audio){const state=result.audio;if(!state.id){audio.pause();audio.removeAttribute('src');audio.load();current='';return result.value;}if(current!==state.id){current=state.id;restore=state.position/1000;audio.src=`mv-audio://song/${state.id}`;audio.load();}else if(Math.abs(audio.currentTime*1000-state.position)>1000)audio.currentTime=state.position/1000;if(state.playing)await audio.play();else audio.pause();}return result?.value??result;}
contextBridge.exposeInMainWorld('miniVoiceWindows',{request:request=>ipcRenderer.invoke('request',request).then(apply)});

ipcRenderer.on('audio',(_,result)=>apply(result).catch(console.error));
ipcRenderer.on('volume',(_,value)=>{audio.volume=value;});
contextBridge.exposeInMainWorld('miniVoice',{platform:'windows',dragArtwork:src=>ipcRenderer.send('editor:dragArtwork',src),command:(action,payload={})=>ipcRenderer.invoke('engine:command',{action,payload}),subscribe:callback=>{const listener=(_,event)=>callback(event);ipcRenderer.on('engine:event',listener);return()=>ipcRenderer.removeListener('engine:event',listener);}});

const mediaCommand=(action,payload={})=>ipcRenderer.invoke('engine:command',{action,payload}).catch(console.error);
if(!new URL(location.href).searchParams.has('surface')&&navigator.mediaSession){
 for(const [action,handler] of Object.entries({play:()=>{if(audio.paused)mediaCommand('toggle');},pause:()=>mediaCommand('pause'),stop:()=>mediaCommand('pause'),previoustrack:()=>mediaCommand('skip',{delta:-1}),nexttrack:()=>mediaCommand('skip',{delta:1}),seekto:details=>mediaCommand('seek',{time:details.seekTime}),seekbackward:details=>mediaCommand('seek',{time:Math.max(0,audio.currentTime-(details.seekOffset||10))}),seekforward:details=>mediaCommand('seek',{time:Math.min(audio.duration||0,audio.currentTime+(details.seekOffset||10))})}))try{navigator.mediaSession.setActionHandler(action,handler);}catch{}
 const update=()=>{navigator.mediaSession.playbackState=audio.paused?'paused':'playing';if(Number.isFinite(audio.duration)&&audio.duration>0)navigator.mediaSession.setPositionState({duration:audio.duration,position:Math.max(0,Math.min(audio.duration,audio.currentTime)),playbackRate:1});};
 for(const event of ['timeupdate','play','pause','loadedmetadata'])audio.addEventListener(event,update);
 ipcRenderer.on('engine:event',(_,message)=>{if(message.event==='state'&&message.data.playing){const song=message.data.playing;navigator.mediaSession.metadata=new MediaMetadata({title:song.title,artist:song.artist,album:song.album});}});
}

ipcRenderer.on('audio:control',async(_,request)=>{try{let value;switch(request.action){case 'devices':value=(await navigator.mediaDevices.enumerateDevices()).filter(device=>device.kind==='audiooutput').map(device=>({id:device.deviceId,name:device.label||'音频输出设备'}));break;case 'sink':if(typeof audio.setSinkId!=='function')throw Error('当前系统不支持输出设备切换');await audio.setSinkId(request.payload.id==='default'?'':request.payload.id);value=true;break;default:throw Error('未知音频操作');}ipcRenderer.send('audio:result',{id:request.id,ok:true,value});}catch(error){ipcRenderer.send('audio:result',{id:request.id,ok:false,error:error.message});}});
let previousOutputs=null;
navigator.mediaDevices?.addEventListener('devicechange',async()=>{try{const outputs=(await navigator.mediaDevices.enumerateDevices()).filter(item=>item.kind==='audiooutput').map(item=>item.deviceId);if(previousOutputs&&audio.sinkId&&audio.sinkId!=='default'&&previousOutputs.includes(audio.sinkId)&&!outputs.includes(audio.sinkId))mediaCommand('pause');previousOutputs=outputs;}catch{}});
