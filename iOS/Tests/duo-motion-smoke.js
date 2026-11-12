// Observe actual UIKit hinge updates; no synthetic pose or CSS variables are injected.
const delay=ms=>new Promise(r=>setTimeout(r,ms));
for(let i=0;i<100&&!document.querySelector('main[data-ready=true]');i++)await delay(100);
if(!document.querySelector('.mv-wall-focused')){document.querySelector('.mv-wall-card')?.click();await delay(800);}
const initial=Boolean(window.miniVoiceFold?.top>0),frames=[];
try{
 const target=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{removeEventListener('minivoice-insets',changed);reject(Error('未收到实际半折/展开状态变化'));},45000);const changed=()=>{const next=Boolean(window.miniVoiceFold?.top>0);if(next===initial)return;clearTimeout(timer);removeEventListener('minivoice-insets',changed);resolve(next);};addEventListener('minivoice-insets',changed);});
 const start=performance.now();
 do{await new Promise(resolve=>requestAnimationFrame(()=>setTimeout(resolve,0)));const main=document.querySelector('main'),r=main.querySelector('.mv-scene').getBoundingClientRect(),upper=main.querySelector('.mv-table-player')?.getBoundingClientRect(),search=main.querySelector('.mv-search-control').getBoundingClientRect();const canvas=main.querySelector('.mv-table-canvas')?.getBoundingClientRect(),focus=main.querySelector('.mv-wall-focused')?.getBoundingClientRect();frames.push({canvasHeight:canvas?.height,focusY:focus?focus.y+focus.height/2:null,focusWidth:focus?.width,t:performance.now()-start,line:r.top,upper:upper?.bottom??null,searchTop:search.top,active:main.dataset.tableMode,moving:main.dataset.foldAnimate});}while(performance.now()-start<800);
 const expected=target?(window.miniVoiceFold.top+window.miniVoiceFold.bottom)/2:0;
 const intermediate=frames.filter(f=>f.line>5&&f.line<Math.max(expected,frames[0].line)-5);
 const aligned=frames.every(f=>f.upper===null||Math.abs(f.upper-f.line)<1);
 const focusStable=frames.every((b,i)=>{const a=frames[i-1];return !a||a.focusY===null||b.focusY===null||(target?b.focusY>=a.focusY-1:b.focusY<=a.focusY+1)&&(target?b.focusWidth<=a.focusWidth+1:b.focusWidth>=a.focusWidth-1);});
 return {focusStable,ok:intermediate.length>0&&aligned&&focusStable&&Math.abs(frames.at(-1).line-expected)<1,initial,target,expected,intermediate:intermediate.length,aligned,frames};
}catch(error){return {ok:false,error:error.message,initial,frames};}
