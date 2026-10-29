const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const wait=async(fn,label)=>{for(let i=0;i<600;i++){if(fn())return;await delay(200);}throw Error(label);};
const button=label=>document.querySelector(`button[aria-label="${label}"]`);
const click=async el=>{if(!el)throw Error('缺少按钮');el.click();await delay(600);};
let serial=900000;
const send=request=>new Promise((resolve,reject)=>{const previous=MiniVoiceTransport.receive,id=String(++serial);MiniVoiceTransport.receive=(key,result)=>{if(key===id){MiniVoiceTransport.receive=previous;result.ok?resolve(result.value):reject(Error(result.error));}else previous(key,result);};MiniVoiceHost.request(id,JSON.stringify({version:1,...request}));});
const rows=[];
try{
 await wait(()=>innerWidth>innerHeight&&document.querySelector('.mv-workspace'),'Duo 尚未展开到横屏');
 for(const [style,label] of [['wall','音乐墙'],['simple','简易'],['library','音乐库']]){
  await click(button('打开侧边栏'));await click(button('设置'));
  await click([...document.querySelectorAll('button')].find(el=>el.textContent.trim()===label));
  await click(button('关闭弹窗'));await click(button('打开侧边栏'));
  const drawer=document.querySelector('.mv-drawer').getBoundingClientRect(),root=getComputedStyle(document.documentElement),safe=parseFloat(root.getPropertyValue('--mv-safe-left'))||0;
  rows.push({style,width:innerWidth,height:innerHeight,left:drawer.left,safe});
  if(innerWidth<=innerHeight||Math.abs(drawer.left-safe-12)>2)throw Error('展开横屏侧栏偏移 '+JSON.stringify(rows));
  await send({kind:'uiTestSnapshot',name:'duo-expanded-'+style});await click(button('关闭侧边栏'));
 }
 return {ok:true,rows};
}catch(error){return {ok:false,error:error.message,rows};}
