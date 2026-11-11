// Observe actual UIKit hinge updates; no synthetic pose or CSS variables are injected.
const delay=ms=>new Promise(r=>setTimeout(r,ms));
for(let i=0;i<100&&!document.querySelector('main[data-ready=true]');i++)await delay(100);
const initial=Boolean(window.miniVoiceFold?.top>0),frames=[];
try{
 const target=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{removeEventListener('minivoice-insets',changed);reject(Error('未收到实际半折/展开状态变化'));},45000);const changed=()=>{const next=Boolean(window.miniVoiceFold?.top>0);if(next===initial)return;clearTimeout(timer);removeEventListener('minivoice-insets',changed);resolve(next);};addEventListener('minivoice-insets',changed);});
 const start=performance.now();
 do{await new Promise(requestAnimationFrame);const main=document.querySelector('main'),r=main.querySelector('.mv-scene').getBoundingClientRect(),upper=main.querySelector('.mv-table-player')?.getBoundingClientRect(),search=main.querySelector('.mv-search-control').getBoundingClientRect();frames.push({t:performance.now()-start,line:r.top,upper:upper?.bottom??null,searchTop:search.top,active:main.dataset.tableMode,moving:main.dataset.foldAnimate});}while(performance.now()-start<800);
 const expected=target?(window.miniVoiceFold.top+window.miniVoiceFold.bottom)/2:0;
 const intermediate=frames.filter(f=>f.line>5&&f.line<Math.max(expected,frames[0].line)-5);
 const aligned=frames.every(f=>f.upper===null||Math.abs(f.upper-f.line)<1);
 return {ok:intermediate.length>0&&aligned&&Math.abs(frames.at(-1).line-expected)<1,initial,target,expected,intermediate:intermediate.length,aligned,frames};
}catch(error){return {ok:false,error:error.message,initial,frames};}
