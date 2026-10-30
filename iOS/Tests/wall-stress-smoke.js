const runtimeErrors=[];addEventListener('error',event=>runtimeErrors.push(event.message));
const checks=[],delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const check=(condition,label)=>{if(!condition)throw Error(label);checks.push(label);};
const wait=async(fn,label)=>{for(let i=0;i<160;i++){if(fn())return;await delay(100);}throw Error(label);};
let serial=800000,peakMounted=0;
const send=request=>new Promise((resolve,reject)=>{const previous=MiniVoiceTransport.receive,id=String(++serial);MiniVoiceTransport.receive=(key,result)=>{if(key===id){MiniVoiceTransport.receive=previous;result.ok?resolve(result.value):reject(Error(result.error));}else previous(key,result);};MiniVoiceHost.request(id,JSON.stringify({version:1,...request}));});
const button=label=>document.querySelector(`button[aria-label="${label}"]`);
const click=async node=>{if(!node)throw Error('missing button');node.click();await delay(450);};
try{
 await wait(()=>document.querySelector('main')?.dataset.ready==='true','mount');
 if(document.querySelector('main').dataset.style!=='wall'){
  await click(button('打开侧边栏'));await click(button('设置'));
  await click([...document.querySelectorAll('button')].find(n=>n.textContent.trim()==='音乐墙'));await click(button('关闭弹窗'));
 }
 await wait(()=>document.querySelector('.mv-wall-card'),'wall');
 const snapshot=await send({kind:'snapshot'});check(snapshot.songs.length===1037,'1037 个合成歌曲身份进入真实 WKWebView');
 const rows=new Map(snapshot.songs.map(song=>[song.id,song]));
 const {createWallProbe}=await import('./wall-smoke-helpers.js');const {probe,camera,box}=createWallProbe({delay});
 await delay(700);
 for(let index=0;index<80;index++){
  const before=camera(),dx=index<40?120:-120;
  const state=await probe({operation:'pan',dx,dy:index%2?40:-40});
  check(Math.abs(state.x-before.x+dx)<1,'大曲库平移不中断 '+index);
  peakMounted=Math.max(peakMounted,state.mounted);check(state.mounted>0&&state.mounted<220,'挂载窗口不随 1037 项曲库扩大 '+index);
 }
 for(let index=0;index<20;index++){
  await probe({operation:'select',index});
  const f=box(),song=rows.get(f?.dataset.wallId);
  check(!!song,'快速切卡身份有效 '+index);
  const visible=[...f.querySelectorAll('.mv-wall-focused-art')].filter(n=>getComputedStyle(n).visibility==='visible');
  check(visible.every(n=>[song.artworkWall,song.artworkCard,song.artwork,song.artworkDetail].includes(n.getAttribute('src'))),'新卡片不会显示上一首封面 '+index);
 }
 await delay(650);
 const f=box(),content=f.querySelector('.mv-wall-focus-content');
 for(const scale of [.6,1.2,.8,1]){
  const state=await probe({operation:'motionZoom',scale});
  check(content.isConnected&&state.contentAligned&&state.maskAligned,'千首库缩放保留同一实时内容和遮罩 '+scale);
 }
 await probe({operation:'endPan'});await delay(700);
 const settled=await probe({});check(settled.visibleBlank===0&&settled.boundedArtwork,'墙面可见封面就绪且像素边长不超过 320');
 const budget=await send({kind:'uiTestArtworkBudget'});
 check(budget.peak>0&&budget.peak<=2&&budget.active<=2,'真实宿主封面读取和缩放并发峰值不超过 2 '+JSON.stringify(budget));
 check(budget.webTerminations===0,'大曲库操作期间 WebContent 未终止');
 check([...box().querySelectorAll('.mv-wall-focused-art')].filter(node=>getComputedStyle(node).visibility==='visible').every(node=>node.naturalWidth<=960&&node.naturalHeight<=960),'普通聚焦封面边长不超过 960');
 await send({kind:'uiTestSnapshot',name:'single-surface-wall-1037'});
 check(runtimeErrors.length===0,'无运行时异常：'+runtimeErrors.join(';'));return {ok:true,scope:'ios-single-surface-1037',peakMounted,checks};
}catch(error){return {ok:false,error:error.message,checks,body:document.body.innerText.slice(0,600)};}
