/** The application owns the animation; the host only persists the style. */
export async function transitionStyle(update,root=document.querySelector('.mv-workspace')){
 const reduced=matchMedia('(prefers-reduced-motion:reduce)').matches;
 if(reduced){await update();return;}
 const frames=()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
 if(document.startViewTransition){
  document.documentElement.dataset.mvStyleTransition='true';
  try{const transition=document.startViewTransition(update);transition.ready.catch(()=>{});transition.updateCallbackDone.catch(()=>{});await transition.finished.catch(()=>{});}finally{delete document.documentElement.dataset.mvStyleTransition;}
 }else{
  await update();await frames();await root?.animate([{opacity:.55,transform:'translateY(8px)'},{opacity:1,transform:'none'}],{duration:360,easing:'cubic-bezier(.22,1,.36,1)'}).finished;
 }
}
