import {presentationFor} from './presentation.js';
/** Only this module knows host APIs. Components speak the same versioned DTO protocol everywhere. */
export function createAndroidTransport(host,timeoutMs=10000,{document:page=globalThis.document,lifecycle=globalThis,now=()=>performance.now(),setTimer=setTimeout,clearTimer=clearTimeout}={}){
  let serial=0,timer=null,last=now();const pending=new Map();
  const pulse=Math.min(500,timeoutMs);
  const resumed=()=>{last=now();for(const entry of pending.values())entry.last=last;};
  page?.addEventListener('visibilitychange',resumed);
  lifecycle.addEventListener?.('pageshow',resumed);
  function tick(){
    timer=null;const timestamp=now(),elapsed=timestamp-last;last=timestamp;
    // A suspended WebView may wake overdue timers before delivering queued replies.
    // Count responsive foreground time, rather than wall time spent suspended.
    if(!page?.hidden&&elapsed<Math.max(2000,pulse*4))for(const [id,entry] of pending){
      entry.remaining-=Math.min(elapsed,timestamp-entry.last);entry.last=timestamp;if(entry.remaining<=0){pending.delete(id);const error=new Error('系统响应超时，请重试');error.code='HOST_TIMEOUT';entry.reject(error);}
    }
    if(pending.size)timer=setTimer(tick,pulse);
  }
  function idle(){if(!pending.size){clearTimer(timer);timer=null;}}
  globalThis.MiniVoiceTransport={receive(id,result){const entry=pending.get(id);if(!entry)return;pending.delete(id);idle();result.ok?entry.resolve(result.value):entry.reject(new Error(result.error||'请求失败'));}};
  const send=request=>new Promise((resolve,reject)=>{
    if(pending.size>=32){reject(new Error('请求繁忙'));return;}
    const id=String(++serial);pending.set(id,{resolve,reject,remaining:timeoutMs,last:now()});if(timer===null){last=now();timer=setTimer(tick,pulse);}
    try{host.request(id,JSON.stringify({...request,version:1}));}catch(error){pending.delete(id);idle();reject(error);}
  });
  send.dispose=()=>{clearTimer(timer);timer=null;page?.removeEventListener('visibilitychange',resumed);lifecycle.removeEventListener?.('pageshow',resumed);for(const entry of pending.values())entry.reject(new Error('宿主连接已关闭'));pending.clear();};
  return send;
}
/** A shared catalog revision prevents retransmitting the entire library with every clock tick. */
export function createSnapshotReader(send){let songs=[],revision='';return async()=>{const value=await send(revision);if(Array.isArray(value.songs))songs=value.songs;revision=String(value.catalogRevision??revision);return {...value,songs};};}
export function platformAdapter(){
  if(globalThis.miniVoiceWindows){const send=request=>globalThis.miniVoiceWindows.request({...request,version:1});return {name:'Windows',presentation:presentationFor({platform:'windows'}),action:(name,payload={})=>send({kind:'action',name,payload}),core:request=>send({kind:'core',request}),snapshot:()=>send({kind:'snapshot'}),play:(id,ids)=>send({kind:'play',id,ids}),toggle:()=>send({kind:'toggle'}),seek:position=>send({kind:'seek',position}),skip:delta=>send({kind:'skip',delta}),read:()=>send({kind:'readState'}),write:state=>send({kind:'writeState',state}),exit:()=>send({kind:'exit'})};}

  if(globalThis.MiniVoiceHost){const send=createAndroidTransport(globalThis.MiniVoiceHost);return {statusBarBlur:globalThis.MiniVoiceHost.platform!=='ios',name:globalThis.MiniVoiceHost.platform==='ios'?'iOS':'Android',portraitDock:globalThis.MiniVoiceHost.platform==='ios'?'center':'leading',styleTransition:globalThis.MiniVoiceHost.platform==='ios'?'host-fragments':'fragments',captureStyle:(payload={})=>send({kind:'captureStyle',...payload}),haptic:()=>globalThis.MiniVoiceHost.haptic?.(),chrome:value=>send({kind:'action',name:'immersive',payload:{value}}),presentation:presentationFor({platform:globalThis.MiniVoiceHost.platform==='ios'?'ios':'android'}),action:(name,payload={})=>send({kind:'action',name,payload}),core:request=>send({kind:'core',request}),snapshot:createSnapshotReader(catalogRevision=>send({kind:'snapshot',catalogRevision})),play:(id,ids)=>send({kind:'play',id,ids}),toggle:()=>send({kind:'toggle'}),seek:position=>send({kind:'seek',position}),skip:delta=>send({kind:'skip',delta}),read:()=>send({kind:'readState'}),write:state=>send({kind:'writeState',state}),exit:()=>send({kind:'exit'})};}
  if(globalThis.miniVoice){const command=globalThis.miniVoice.command;return {name:'macOS',presentation:presentationFor({platform:'macos'}),action:(name,payload={})=>command(name==='settings'?'openSettings':name==='queueSelect'?'play':name,name==='mode'?{value:['single','list','shuffle','repeatOne','repeatAll'][payload.value]}:payload),core:request=>command('sharedCore',request),snapshot:async()=>{const value=await command('portableSnapshot');return {...value,mode:['single','list','shuffle','repeatOne','repeatAll'].indexOf(value.mode)};},play:(id,ids)=>command('play',{id,ids}),toggle:()=>command('toggle'),seek:position=>command('seek',{time:position/1000}),skip:delta=>command('skip',{delta}),read:async()=>JSON.parse(localStorage.getItem('minivoice.portable.v1')||'{}'),write:async state=>localStorage.setItem('minivoice.portable.v1',JSON.stringify(state)),exit:()=>command('portableExit')};}
  const send=async request=>{const response=await fetch('/api/request',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({...request,version:1})});const result=await response.json();if(!result.ok)throw new Error(result.error||'预览服务不可用');return result.value;};
  return {name:'演示音乐库',demo:true,presentation:presentationFor({platform:'browser',deviceClass:'phone'}),action:(name,payload={})=>send({kind:'action',name,payload}),core:request=>send({kind:'core',request}),snapshot:createSnapshotReader(catalogRevision=>send({kind:'snapshot',catalogRevision})),play:(id,ids)=>send({kind:'play',id,ids}),toggle:()=>send({kind:'toggle'}),seek:position=>send({kind:'seek',position}),skip:delta=>send({kind:'skip',delta}),read:async()=>JSON.parse(localStorage.getItem('minivoice.preview.v1')||'{}'),write:async state=>localStorage.setItem('minivoice.preview.v1',JSON.stringify(state)),exit:async()=>{}};
}
