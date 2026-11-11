// Real WKWebView and system posture only; exclusively synthetic simulator library.
const delay=ms=>new Promise(r=>setTimeout(r,ms)),rows=[],failures=[];
const wait=async(fn,label)=>{for(let i=0;i<120;i++){if(fn())return;await delay(100);}throw Error(label);};
let serial=800000;
const send=request=>new Promise((resolve,reject)=>{const previous=MiniVoiceTransport.receive,id=String(++serial);MiniVoiceTransport.receive=(key,result)=>{if(key===id){MiniVoiceTransport.receive=previous;result.ok?resolve(result.value):reject(Error(result.error));}else previous(key,result);};MiniVoiceHost.request(id,JSON.stringify({version:1,...request}));});
const button=label=>[...document.querySelectorAll('button')].find(e=>e.getAttribute('aria-label')===label&&!e.closest('[hidden]'));
const text=value=>[...document.querySelectorAll('button')].find(e=>e.textContent.trim().replace('✓','')===value);
const click=async(e,label)=>{if(!e)throw Error('missing '+label);e.click();await delay(350);};
const close=async()=>{for(let i=0;i<4;i++){const e=button('关闭弹窗')||button('关闭侧边栏');if(!e)break;await click(e,'close');}};
const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom};};
const record=async(style,theme,page)=>{
 const main=document.querySelector('main'),fold=window.miniVoiceFold||{},lower=main.dataset.tableMode==='true'?(fold.top+fold.bottom)/2:0;
 const selectors={scene:'.mv-scene',toolbar:'.mv-toolbar',drawer:'.mv-drawer-shade[data-open=true] .mv-drawer',modal:'.mv-modal',dock:'.mv-dock',hero:'.mv-hero',lyrics:'.mv-lyrics',table:'.mv-table-player'};
 const boxes=Object.fromEntries(Object.entries(selectors).flatMap(([key,selector])=>{const e=document.querySelector(selector);return e&&getComputedStyle(e).display!=='none'&&e.getBoundingClientRect().height>0?[[key,rect(e)]]:[]}));
 const row={style,theme,page,width:innerWidth,height:innerHeight,fold,table:main.dataset.tableMode,boxes};rows.push(row);
 for(const key of ['drawer','modal','dock','toolbar']){const r=boxes[key];if(!r)continue;if(r.x<-.6||r.y<lower-.6||r.right>innerWidth+.6||r.bottom>innerHeight+.6)failures.push({...row,reason:key+' outside active region'});}
 const active=[...document.querySelectorAll('.mv-scene button,.mv-modal button,.mv-drawer-shade[data-open=true] button')].filter(e=>!e.closest('[hidden]')&&!e.disabled&&getComputedStyle(e).visibility!=='hidden'&&e.getBoundingClientRect().height>0);
 row.clippedActions=active.filter(e=>{const r=e.getBoundingClientRect(),p=e.closest('.mv-modal-content,.mv-drawer nav,.mv-song-list,.mv-lyric-lines,.mv-cover-wall');return !p&&(r.x<-.6||r.right>innerWidth+.6||r.y<lower-.6||r.bottom>innerHeight+.6);}).map(e=>({label:e.getAttribute('aria-label')||e.textContent.slice(0,32),...rect(e)}));
 if(row.clippedActions.length)failures.push({...row,reason:'clipped actions'});
 await send({kind:'uiTestSnapshot',name:`matrix-${style}-${theme}-${page}`});
};
try{
 await wait(()=>document.querySelector('main[data-ready=true]'),'ready');
 for(const [style,label] of [['simple','简易'],['library','音乐库'],['wall','音乐墙']])for(const [theme,themeLabel] of [['light','浅色模式'],['dark','深色模式']]){
  await close();await click(button('打开侧边栏'),'drawer');await click(button('设置'),'settings');await click([...document.querySelectorAll('.mv-style-picker button')].find(e=>e.textContent.trim()===label),label);await wait(()=>document.querySelector('main').dataset.style===style,'style switch '+style);await click(text(themeLabel),themeLabel);await close();await delay(500);
  if(style==='library'&&text('返回'))await click(text('返回'),'library catalog');
  await record(style,theme,'main');
  await click(button('打开侧边栏'),'drawer');await record(style,theme,'drawer');await click(button('设置'),'settings');await record(style,theme,'settings');await close();
  await click(button('搜索音乐'),'search');await record(style,theme,'search');document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));await delay(300);
  if(style!=='wall'){
   const now=button('展开正在播放');if(now)await click(now,'player');await record(style,theme,'player');
   if(button('展开歌词')){await click(button('展开歌词'),'lyrics');await record(style,theme,'lyrics');await click(button('收起歌词'),'collapse lyrics');}
  }else{await click(document.querySelector('.wp-dock-meter'),'dock');const locate=document.querySelector('.wp-dock-content .mv-now');await click(locate,'locate');await record(style,theme,'focus');}
  await click(button('播放队列'),'queue');await record(style,theme,'queue');await close();
  for(const [i,label] of (style==='simple'?['音乐库','最近播放']:['音乐库','最近播放','收藏','歌手','专辑']).entries()){await click(button('打开侧边栏'),'navigation');const nav=[...document.querySelectorAll('.mv-drawer nav button')].find(e=>e.textContent.trim()===label);await click(nav,label);await record(style,theme,'section-'+i);}
  if(style!=='simple'){await click(button('打开侧边栏'),'create playlist');await click(text('新建歌单'),'create playlist');await record(style,theme,'create-playlist');await close();}
 }
 return {ok:!failures.length,rows,failures};
}catch(error){return {ok:false,error:error.message,rows,failures};}
