// Runs in the real iOS WKWebView only with an explicit simulator test argument.
const checks=[];
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const wait=async(fn,label)=>{for(let i=0;i<100;i++){const value=fn();if(value)return value;await delay(100);}throw Error('等待超时：'+label+'; '+document.body.innerText.slice(0,600));};
const check=(value,label)=>{if(!value)throw Error(label);checks.push(label);};
const button=label=>[...document.querySelectorAll('button')].find(el=>el.getAttribute('aria-label')===label&&!el.closest('[hidden]'));
const textButton=text=>[...document.querySelectorAll('button')].find(el=>el.textContent.trim()===text&&!el.closest('[hidden]'));
const click=async(el,label)=>{check(!!el,label+'存在');el.click();await delay(400);};
let serial=100000;
const send=request=>new Promise((resolve,reject)=>{
 const previous=globalThis.MiniVoiceTransport.receive;
 const id=String(++serial);
 globalThis.MiniVoiceTransport.receive=(key,result)=>{if(key===id){globalThis.MiniVoiceTransport.receive=previous;result.ok?resolve(result.value):reject(Error(result.error));}else previous(key,result);};
 MiniVoiceHost.request(id,JSON.stringify({version:1,...request}));
});
try {
 await wait(()=>document.querySelector('.mv-workspace'),'共享页面挂载');
 await wait(()=>document.querySelector('.mv-wall-card'),'音乐墙封面');
 check(document.querySelector('.mv-workspace').dataset.presentation==='mobile','iOS 使用 Android 触控家族');
 const snapshot=await send({kind:'snapshot'});
 check(snapshot.songs.length===12,'合成音乐库通过真实宿主桥读取');
 check(snapshot.songs.every(song=>song.duration===60000),'秒转毫秒协议');
 await wait(()=>[...document.images].filter(img=>img.src.includes('/artwork/')).some(img=>img.complete&&img.naturalWidth>0),'宿主封面加载');
 checks.push('授权封面资源加载成功');
 const dock=document.querySelector('.mv-wall-dock');
 const centerError=()=>{const r=dock.getBoundingClientRect(),s=getComputedStyle(document.querySelector('main'));return Math.abs(r.left+r.width/2-(innerWidth+parseFloat(s.getPropertyValue('--mv-safe-left')||'0')-parseFloat(s.getPropertyValue('--mv-safe-right')||'0'))/2);};
 if(innerHeight>=innerWidth){
   check(centerError()<1.5,'竖屏展开播放条左右居中');
   await delay(450);
   const settings=document.querySelector('[data-wall-control=settings]');
   const restingBottom=14+(parseFloat(getComputedStyle(document.querySelector('main')).getPropertyValue('--mv-safe-bottom'))||0);
   const expandedSettingsBottom=innerHeight-settings.getBoundingClientRect().bottom;
   if(innerWidth>=600)check(Math.abs(expandedSettingsBottom-restingBottom)<1.5,'iPad 展开长条不遮挡设置时设置保留原位 '+expandedSettingsBottom+'/'+restingBottom);
   else check(expandedSettingsBottom>restingBottom+50,'手机长条实际遮挡时设置上移');
   document.activeElement?.blur();
   const samples=[];const began=performance.now();
   await new Promise(resolve=>{function sample(){const r=dock.getBoundingClientRect();samples.push({width:r.width,left:r.left,right:r.right});if(performance.now()-began<3700)requestAnimationFrame(sample);else resolve();}sample();});
   check(dock.classList.contains('is-compact'),'播放条空闲收起');
   const compactRect=dock.getBoundingClientRect();
   const safeLeft=parseFloat(getComputedStyle(document.querySelector('main')).getPropertyValue('--mv-safe-left')||'0');
   check(Math.abs(compactRect.left-safeLeft-14)<1.5,'收起圆形保留原左下角位置');
   check(samples.every(value=>value.left>=-1&&value.right<=innerWidth+1),'长条到圆形过渡不越出屏幕');
   check(samples.some(value=>value.width>57&&value.width<300),'实际采样到播放条变形中间帧');
   await send({kind:'uiTestSnapshot',name:'dock-compact-leading'});
   dock.dispatchEvent(new PointerEvent('pointerover',{bubbles:true,pointerType:'mouse',relatedTarget:document.body}));
   await delay(250);
   check(dock.classList.contains('is-compact'),'触控家族鼠标悬停不展开圆形');
   dock.dispatchEvent(new PointerEvent('pointerout',{bubbles:true,pointerType:'mouse',relatedTarget:document.body}));
   await click(button('展开播放条'),'恢复展开播放条');await delay(450);
   check(document.querySelector('.mv-wall-dock')===dock,'圆形和长条保留同一材质节点');
   check(centerError()<1.5,'再次展开后长条左右居中');
   if(innerWidth>=600)check(Math.abs((innerHeight-settings.getBoundingClientRect().bottom)-expandedSettingsBottom)<1.5,'iPad 圆形与长条切换时设置不跳位');
   document.documentElement.style.setProperty('--mv-safe-left','44px');
   document.documentElement.style.setProperty('--mv-safe-right','12px');
   await delay(500);
   check(centerError()<1.5,'非对称安全区内展开长条居中');
   for(const side of ['left','right'])document.documentElement.style.setProperty('--mv-safe-'+side,'env(safe-area-inset-'+side+',0px)');
   await delay(500);
   check(centerError()<1.5,'恢复系统安全区后仍居中');
 }
 await send({kind:'uiTestSnapshot',name:'wall'});
 await click(button('打开侧边栏')||button('侧边栏'),'侧边栏');
 await wait(()=>document.querySelector('.mv-drawer'),'抽屉显示');
 check(!!document.querySelector('.mv-drawer [data-mv-component="action-button"]'),'抽屉复用 ActionButton');
 await click(button('设置'),'设置');
 await wait(()=>document.querySelector('.mv-mobile-settings'),'共享设置面板');
 await wait(()=>document.body.textContent.includes('合成测试音乐'),'文件夹设置');
 checks.push('共享设置读取 iOS 授权目录');
 await send({kind:'uiTestSnapshot',name:'settings-dark'});
 const before=await send({kind:'readState'});
 await click(textButton('浅色模式'),'浅色主题');
 await wait(()=>document.querySelector('.theme-light'),'浅色主题应用');
 check((await send({kind:'readState'})).pages.appearance.theme==='light','主题通过共享状态持久化');
 await send({kind:'uiTestSnapshot',name:'settings-light'});
 await click(textButton('深色模式'),'深色主题');
 await wait(()=>document.querySelector('.theme-dark'),'深色主题应用');
 // Platform commands must reject forged identities without changing playback.
 let denied=false;try{await send({kind:'play',id:'not-authorized',ids:['not-authorized']});}catch{denied=true;}
 check(denied,'拒绝未授权歌曲');
 await send({kind:'play',id:snapshot.songs[1].id,ids:snapshot.songs.map(song=>song.id)});
 check((await send({kind:'snapshot'})).current===snapshot.songs[1].id,'真实 AVPlayer 切歌接入');
 await send({kind:'seek',position:12000});
 check(Math.abs((await send({kind:'snapshot'})).position-12000)<1000,'播放进度毫秒转秒');
 await send({kind:'toggle'});
 let modeDenied=false;try{await send({kind:'action',name:'mode',payload:{value:99}});}catch{modeDenied=true;}
 check(modeDenied,'拒绝无效播放模式');
 const playlist=await send({kind:'action',name:'createPlaylist',payload:{name:'iOS 桥接验证',ids:[snapshot.songs[0].id]}});
 const updated=await send({kind:'snapshot'});
 check(updated.playlists.some(p=>p.id===playlist.id&&p.ids[0]===snapshot.songs[0].id),'共享歌单操作保存回读');
 await send({kind:'action',name:'deletePlaylist',payload:{playlist:playlist.id}});
 await send({kind:'action',name:'mode',payload:{value:4}});
 check((await send({kind:'snapshot'})).mode===4,'五种播放模式接入');
 await click(button('关闭弹窗'),'关闭设置');
 await wait(()=>!document.querySelector('.mv-modal'),'设置关闭完成');
 await click(button('音乐墙设置'),'音乐墙设置');
 await wait(()=>document.querySelector('[aria-label="显示比例"]'),'共享比例滑块');
 const reset=textButton('恢复 100%');
 if(reset&&!reset.disabled)await click(reset,'恢复比例');
 await click(button('放大'),'放大封面');
 check(Math.abs((await send({kind:'readState'})).pages['音乐库\n'].camera.scale-1.1)<0.01,'墙比例经共享相机持久化');
 await click(button('关闭弹窗'),'关闭墙设置');
 await delay(500);
 const meter=button('展开播放条');
 if(meter)await click(meter,'展开播放条');
 await click(button('播放队列'),'播放队列');
 await wait(()=>document.querySelector('.mv-queue-list .mv-song'),'共享队列歌曲');
 checks.push('队列复用共享虚拟列表');
 await send({kind:'uiTestSnapshot',name:'queue'});
 await click(button('关闭弹窗'),'关闭队列');
 await delay(500);
 await click(button('打开侧边栏'),'再次打开侧栏');
 await send({kind:'uiTestSnapshot',name:'drawer'});
 await click(button('设置'),'再次打开设置');
 await wait(()=>document.querySelector('.mv-mobile-settings'),'设置重开');
 for(const [label,style] of [['简易','simple'],['音乐库','library'],['音乐墙','wall']]) {
   await click(textButton(label),label+'样式');
   await wait(()=>document.querySelector('.style-'+style),label+'应用');
   check((await send({kind:'readState'})).pages.appearance.style===style,label+'样式持久化');
   await send({kind:'uiTestSnapshot',name:style+'-settings'});
 }
 // Leave the shared settings open for a deterministic native screenshot.
 return {ok:true,checks,viewport:{width:innerWidth,height:innerHeight},state:before,body:document.body.innerText.slice(0,800)};
} catch(error) { return {ok:false,error:error.message,checks,body:document.body.innerText.slice(0,1200)}; }
