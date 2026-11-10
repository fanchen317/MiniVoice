// Each segment owns its easing. Applying this ease to the whole timeline moves
// the intended halfway peak into the first few release frames.
export function releaseKeyframes(from,peak){
 return [{scale:String(from),offset:0,easing:'cubic-bezier(.22,.9,.25,1)'},{scale:String(peak),offset:.5,easing:'cubic-bezier(.4,0,.2,1)'},{scale:'.992',offset:.78,easing:'ease-out'},{scale:'1',offset:1}];
}
export function animateButtonRelease(node,{from,peak,root=document.documentElement,media=matchMedia('(prefers-reduced-motion:reduce)')}={}){
 // CSS :active transitions outrank WAAPI animations. End only the scale
 // transition so it cannot swallow the first release segment or alter a morph.
 for(const animation of node.getAnimations())if(animation.transitionProperty==='scale')animation.cancel();
 const animation=node.animate(releaseKeyframes(from,peak),{duration:380,easing:'linear'});
 const cleanup=()=>{observer.disconnect();media.removeEventListener('change',changed);};
 const cancel=()=>{cleanup();animation.cancel();};
 const changed=()=>{if(root.classList.contains('reduce-motion')||media.matches)cancel();};
 const observer=new MutationObserver(changed);observer.observe(root,{attributes:true,attributeFilter:['class']});media.addEventListener('change',changed);
 animation.finished.then(cleanup,cleanup);
 return {cancel};
}
