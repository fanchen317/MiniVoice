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
 const initialState=await send({kind:'readState'});
 const initialSnapshot=await send({kind:'snapshot'});
 const initialStyle=initialState.pages?.appearance?.style||initialSnapshot.style||'library';
 await wait(()=>document.querySelector('.mv-workspace')?.dataset.style===initialStyle,'恢复已保存样式');
 if(initialStyle!=='wall'){
   await click(button('打开侧边栏'),'初始化测试侧栏');await click(button('设置'),'初始化测试设置');
   await click(textButton('音乐墙'),'初始化音乐墙');await click(button('关闭弹窗'),'关闭初始化设置');
 }
 await wait(()=>document.querySelector('.mv-wall-card'),'音乐墙封面');
 check(document.querySelector('.mv-workspace').dataset.presentation==='mobile','iOS 使用 Android 触控家族');
 // Exercise the real iOS host policy through the branded style switch.
 let captureCalls=0,fragmentPreparations=0,fragmentAnimations=0;const requestBefore=MiniVoiceHost.request;
 MiniVoiceHost.request=function(id,raw){const request=JSON.parse(raw);if(request.kind==='captureStyle'){captureCalls++;if(request.phase==='prepare')fragmentPreparations++;if(request.phase==='animate')fragmentAnimations++;}return requestBefore.call(this,id,raw);};
 await click(button('打开侧边栏'),'切换渲染测试侧栏');
 for(const target of ['simple','library','wall']){
   document.querySelector('.mv-brand-logo').click();
   await wait(()=>document.querySelector('main').dataset.styleBusy==='false'&&document.querySelector('main').dataset.style===target,'实时样式切换 '+target);
   check(!document.querySelector('.mv-style-fragment-sweep'),'WK 切换无分片截图层 '+target);
   check(getComputedStyle(document.querySelector('main')).opacity==='1','WK 切换结束恢复不透明 '+target);
 }
 check(fragmentPreparations===3&&fragmentAnimations===3,'iOS 三次切换均使用原生碎片动画');MiniVoiceHost.request=requestBefore;
 await click(button('关闭侧边栏'),'关闭渲染测试侧栏');
 const panWall=document.querySelector('.mv-cover-wall');
 check(getComputedStyle(panWall).overflowX==='auto'&&panWall.scrollWidth>innerWidth*6,'WK 原生双轴滚动承载墙面');
 panWall.scrollLeft+=120;panWall.scrollTop+=80;await delay(200);
 check(Math.abs(JSON.parse(document.querySelector('.mv-wall-plane').dataset.camera).x-12)>1,'WK 原生滚动同步相机');
 for(let i=0;i<12;i++){panWall.dispatchEvent(new WheelEvent('wheel',{deltaX:i<6?100:-100,deltaY:40,bubbles:true,cancelable:true}));await delay(20);}
 await delay(700);
 check(document.querySelector('.mv-wall-plane').dataset.compositedPan==='true','WK 连续滑动保留容器合成');
 const visiblePosters=[...document.querySelectorAll('.mv-wall-card img')].filter(image=>{const r=image.getBoundingClientRect();return r.right>0&&r.left<innerWidth&&r.bottom>0&&r.top<innerHeight;});
 await wait(()=>visiblePosters.every(image=>image.complete&&image.naturalWidth>0),'WK 往返滑动封面加载');
 check(visiblePosters.length>0,'WK 滑动后可见封面非空');

 const snapshot=await send({kind:'snapshot'});
 check(snapshot.songs.length===12,'合成音乐库通过真实宿主桥读取');
 check(snapshot.songs.every(song=>song.duration===60000),'秒转毫秒协议');
 await wait(()=>[...document.images].filter(img=>img.src.includes('/artwork/')).some(img=>img.complete&&img.naturalWidth>0),'宿主封面加载');
 checks.push('授权封面资源加载成功');
 check(getComputedStyle(document.querySelector('.mv-workspace')).webkitUserSelect==='none','移动内容禁止系统文本多选');
 check(snapshot.songs.every(song=>song.id.includes('/')&&song.id.includes('#')&&song.sourceAdded>0&&song.added>0&&song.size>0),'真实路径身份与日期和大小字段');
 for(const song of snapshot.songs){
   for(const url of [song.artwork,song.artworkDetail]){
     const img=new Image();img.src=url;await wait(()=>img.complete,'封面请求完成');check(img.naturalWidth>0,'特殊路径缩略图及原图 '+song.title);
   }
 }
 const action=(name,payload={})=>send({kind:'action',name,payload});
 const config=await action('getSettings');
 check(['cacheInfo','clearCache','inspectLibrary','artistAlias','clearArtistAliases','exportDiagnostics'].every(key=>config.actions.includes(key)),'维护设置能力完整接入');
 const cache=await action('cacheInfo');check(cache.count>=12&&cache.bytes>0,'封面缓存统计');
 let cacheDenied=false;try{await action('clearCache',{ids:['../outside']});}catch{cacheDenied=true;}
 check(cacheDenied&&(await action('cacheInfo')).count===cache.count,'拒绝越界缓存清理并保留缓存');
 await action('inspectLibrary',{start:true});
 let inspected;for(let i=0;i<100;i++){inspected=await action('inspectLibrary');if(!inspected.running)break;await delay(50);}
 check(inspected.checked===12&&inspected.unavailable.length===0,'真实文件读取巡检完成');
 const [source,target]=config.artists;
 await action('artistAlias',{source,target});
 check((await send({kind:'snapshot'})).songs.filter(song=>song.artist===target).length>snapshot.songs.filter(song=>song.artist===target).length,'歌手别名应用到目录');
 await action('clearArtistAliases');
 check(Object.keys((await action('getSettings')).aliases).length===0,'清空歌手别名');
 const dock=document.querySelector('.mv-wall-dock');
 // Earlier rendering probes deliberately take longer than the idle-collapse timer.
 if(dock.classList.contains('is-compact'))await click(button('展开播放条'),'初始化展开播放条');
 dock.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,pointerType:'touch'}));
 dock.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,pointerType:'touch'}));
 await delay(450);
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

 // Exercise the actual WKWebView chrome, including the centered iOS bar skin.
 if(document.querySelector('.mv-wall-focused [aria-label="收起播放器"]')){document.querySelector('.mv-wall-focused [aria-label="收起播放器"]').click();await delay(900);}
 document.querySelector('.mv-wall-card').click();await delay(600);
 const chromeNodes=()=>[document.querySelector('.mv-toolbar>[aria-label="打开侧边栏"]'),document.querySelector('.mv-search-control'),document.querySelector('[data-wall-control="settings"]'),document.querySelector('.mv-wall-dock')];
 for(const compact of [false,true]){
   document.activeElement?.blur();
   if(compact){await wait(()=>dock.classList.contains('is-compact'),'动画测试圆形状态');await delay(450);}
   else if(dock.classList.contains('is-compact')){button('展开播放条').click();await delay(450);}
   const before=chromeNodes().map(n=>n.getBoundingClientRect());
   document.querySelector('.mv-wall-focused [aria-label="展开播放器"]').click();await delay(100);
   const moving=chromeNodes().map(n=>({r:n.getBoundingClientRect(),s:getComputedStyle(n)}));
   check(moving.every((v,i)=>v.s.visibility==='visible'&&+v.s.opacity>0&&+v.s.opacity<1&&(i===0?v.r.x<before[i].x:i===1?v.r.x>before[i].x:v.r.y>before[i].y)),'WK 四个入口有分向移出中间帧 '+compact);
   await delay(450);check(chromeNodes().every(n=>getComputedStyle(n).visibility==='hidden'),'WK 四个入口完全退场 '+compact);
   await delay(3200);check(dock.classList.contains('is-compact')===compact,'WK 退场期间保留横条或圆形 '+compact);
   document.querySelector('.mv-wall-focused [aria-label="收起播放器"]').click();await delay(100);
   check(document.querySelector('main').dataset.wallChrome==='hidden','WK 插图缩回期间入口仍在屏外 '+compact);
   await delay(360);check(document.querySelector('main').dataset.wallChrome==='entering','WK 插图缩回后入口有返回阶段 '+compact);
   await delay(450);check(document.querySelector('.mv-wall-dock')===dock&&dock.classList.contains('is-compact')===compact,'WK 返回保留播放栏节点和形态 '+compact);
 }
 if(dock.classList.contains('is-compact')){button('展开播放条').click();await delay(450);}
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
 check(!document.body.textContent.includes('歌手名称归并')&&!document.body.textContent.includes('保存归并规则'),'移动设置移除未开放归并入口');
 await click(textButton('深色模式'),'深色主题');
 await wait(()=>document.querySelector('.theme-dark'),'深色主题应用');
 // Platform commands must reject forged identities without changing playback.
 let denied=false;try{await send({kind:'play',id:'not-authorized',ids:['not-authorized']});}catch{denied=true;}
 check(denied,'拒绝未授权歌曲');
 await send({kind:'play',id:snapshot.songs[1].id,ids:snapshot.songs.map(song=>song.id)});
 check((await send({kind:'snapshot'})).current===snapshot.songs[1].id,'真实本地音频播放器切歌接入');
 await send({kind:'seek',position:12000});
 check(Math.abs((await send({kind:'snapshot'})).position-12000)<1000,'播放进度毫秒转秒');
 await send({kind:'toggle'});
 let modeDenied=false;try{await send({kind:'action',name:'mode',payload:{value:99}});}catch{modeDenied=true;}
 check(modeDenied,'拒绝无效播放模式');
 const playlist=await send({kind:'action',name:'createPlaylist',payload:{name:'iOS 桥接验证',ids:[snapshot.songs[0].id]}});
 const updated=await send({kind:'snapshot'});
 check(updated.playlists.some(p=>p.id===playlist.id&&p.ids[0]===snapshot.songs[0].id),'共享歌单操作保存回读');
 await send({kind:'action',name:'deletePlaylist',payload:{playlist:playlist.id}});
 for(let value=0;value<5;value++){await send({kind:'action',name:'mode',payload:{value}});check((await send({kind:'snapshot'})).mode===value,'播放模式 '+value+' 接入');}
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
   if(style!=='wall'){
     await click(button('关闭弹窗'),'检查背景材质前关闭设置');
     if(style==='library'&&!document.querySelector('main').classList.contains('is-player'))await click(button('正在播放'),'打开音乐库播放器');
     const materials=()=>[...document.querySelectorAll('.mv-scene .mv-glass,.mv-scene .mv-dock,.mv-scene .mv-search-control,.mv-scene .mv-toolbar>.mv-button')].filter(n=>n.getClientRects().length).map(n=>{const s=getComputedStyle(n);return [s.backgroundColor,s.backgroundImage,s.borderTopColor,s.borderTopWidth,s.boxShadow,s.backdropFilter,s.borderRadius];});
     await delay(450);const originalMaterials=JSON.stringify(materials());
     await click(button('打开侧边栏'),'检查背景材质时打开侧栏');
     check(JSON.stringify(materials())===originalMaterials,'WK '+style+' 侧栏打开保留背景组件材质与轮廓');
     check(document.querySelector('.mv-scene').inert,'WK '+style+' 侧栏打开禁止背景交互');
     await send({kind:'uiTestSnapshot',name:style+'-drawer-surfaces'});
     await click(button('关闭侧边栏'),'背景材质检查后关闭侧栏');
     check(JSON.stringify(materials())===originalMaterials,'WK '+style+' 侧栏关闭保留原材质');
     await click(button('打开侧边栏'),'回到侧栏设置');await click(button('设置'),'继续设置检查');
   }

 }
 // Exercise the actual scanner after layout snapshots, not just preconstructed Song rows.
 await action('rescan');
 let scanned;for(let i=0;i<150;i++){scanned=await send({kind:'snapshot'});if(!scanned.scanning)break;await delay(100);}
 check(!scanned.scanning&&scanned.songs.length===12,'真实目录扫描完成且不丢歌');
 check(scanned.songs.every(song=>song.sourceAdded>0&&song.size>0&&song.artworkDetail),'扫描回填日期大小和原封面');
 await send({kind:'play',id:scanned.songs[0].id,ids:scanned.songs.map(song=>song.id)});
 check((await send({kind:'snapshot'})).rawLyrics.includes('根目录逐字歌词'),'扫描发现根目录 YRC 歌词');
 await send({kind:'toggle'});
 // Warm every versioned resource before taking the cache inventory: the live
 // wall may still be requesting the newly scanned catalog on its 450ms poll.
 await delay(600);
 for(const song of scanned.songs)for(const url of [song.artwork,song.artworkDetail].filter(Boolean)){
   const image=new Image();image.src=url;await wait(()=>image.complete,'清理前显示资源完成');check(image.naturalWidth>0,'清理前显示资源可读');
 }
 const original=await action('cacheInfo');
 const cleared=await action('clearCache');
 check(cleared.removed===original.count,'清理仅移除已枚举缓存 '+cleared.removed+'/'+original.count);
 check((await action('cacheInfo')).count===0,'缓存清理结果回读');
 const restored=new Image();
 restored.src=scanned.songs[0].artwork.replace(/v=[^&]*/, 'v=after-clear');
 await wait(()=>restored.complete,'清理后封面重建');check(restored.naturalWidth>0,'缓存清理后从授权原文件重建封面');
 await action('inspectLibrary',{start:true});
 for(let i=0;i<100;i++){inspected=await action('inspectLibrary');if(!inspected.running)break;await delay(50);}
 check(inspected.checked===12&&inspected.unavailable.length===0,'缓存清理保留全部原始音频');
 const stress=await send({kind:'uiTestScanStress'});
 check(stress.count===1037&&stress.incrementalCount===1037&&stress.errors===0&&stress.thumbnailsBounded,'1037 首混合格式/4096px 封面完整扫描与增量重扫 '+JSON.stringify(stress));
 check(stress.displayBounded&&stress.originalRetained,'4096px 原封面生成 2048px 展示资源且原图字节保留');
 check(stress.baselineBytes>0&&stress.growthBytes<300*1024*1024,'大库扫描采样内存增长低于 300 MiB');
 const audioProbe=await send({kind:'uiTestAudioFormats'});
 check(audioProbe.rows.length===2&&audioProbe.rows.every(row=>row.state==='playing'&&row.position>0.2&&row.duration>0.5&&!row.error),'真实 MP3/FLAC 解码并推进播放时钟 '+JSON.stringify(audioProbe.rows));
 check(audioProbe.rapidSelectionSettled,'连续切歌期间暂停/定位保留且旧加载结果不覆盖');
 check(audioProbe.flacArtwork,'真实 FLAC PICTURE 块经扫描生成封面');
 check(audioProbe.maximumPageZoom<=1.001&&Math.abs(audioProbe.pageZoom-1)<0.001&&Math.abs(visualViewport.scale-1)<0.001,'整页缩放禁用且页面比例为 1 '+JSON.stringify({native:audioProbe.pageZoom,max:audioProbe.maximumPageZoom,scale:visualViewport.scale}));
 const diagnostics=await send({kind:'uiTestDiagnostics'});
 check(diagnostics.bytes>500&&Number.isInteger((await action('getSettings')).crashCount),'诊断包含事件记录并返回真实本地崩溃数量');
 // Leave the shared settings open for a deterministic native screenshot.
 return {ok:true,checks,viewport:{width:innerWidth,height:innerHeight},state:before,body:document.body.innerText.slice(0,800)};
} catch(error) { return {ok:false,error:error.message,checks,body:document.body.innerText.slice(0,1200)}; }
