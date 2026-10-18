// A wrapped timed word consumes the first visual fragment before continuing
// onto the next line, exactly like LyricsSweepRenderer's accumulated glyphs.
export function filledFragments(widths,progress){
  let remaining=widths.reduce((sum,width)=>sum+width,0)*Math.max(0,Math.min(1,progress));
  return widths.map(width=>{const filled=Math.min(width,Math.max(0,remaining));remaining-=width;return filled;});
}
const layouts=new WeakMap();
export function paintLyricSweep(surface,time,{reduced=false,wall=false}={}){
  if(!surface||!surface.offsetWidth||!surface.offsetHeight)return;
  const words=[...surface.querySelectorAll('[data-word-start]')];
  if(!words.length){surface.classList.remove('sweep-surface');surface.style.backgroundImage='';return;}
  const signature=`${surface.clientWidth}:${surface.clientHeight}:${getComputedStyle(surface).fontSize}:${words.map(word=>word.textContent).join('|')}`;
  let cached=layouts.get(surface);
  if(!cached||cached.signature!==signature||cached.first!==words[0]){
    const origin=surface.getBoundingClientRect(),scaleX=origin.width/Math.max(1,surface.offsetWidth),scaleY=origin.height/Math.max(1,surface.offsetHeight);
    const ranges=words.map(word=>{
      const range=document.createRange();range.selectNodeContents(word);
      const fragments=[...range.getClientRects()].filter(rect=>rect.width>0).map(rect=>({x:(rect.left-origin.left)/scaleX,y:(rect.top-origin.top)/scaleY-2,width:rect.width/scaleX,height:rect.height/scaleY+4}));
      return {word,fragments};
    });
    const fragments=ranges.flatMap(range=>range.fragments),color=wall?'#fff':'#0fa875',pending=wall?'#ffffff70':'#0fa87561';
    surface.classList.add('sweep-surface');
    surface.style.backgroundImage=[...fragments.map(()=>`linear-gradient(${color},${color})`),`linear-gradient(${pending},${pending})`].join(',');
    surface.style.backgroundPosition=[...fragments.map(rect=>`${rect.x}px ${rect.y}px`),'0 0'].join(',');
    cached={signature,first:words[0],ranges};layouts.set(surface,cached);
  }
  const sizes=[];
  for(const {word,fragments} of cached.ranges){
    const start=Number(word.dataset.wordStart),end=Number(word.dataset.wordEnd);
    const progress=reduced?1:Math.max(0,Math.min(1,(time-start)/Math.max(.01,end-start)));
    word.style.setProperty('--word-progress',`${progress*100}%`);
    filledFragments(fragments.map(fragment=>fragment.width),progress).forEach((width,i)=>sizes.push(`${width}px ${fragments[i].height}px`));
  }
  surface.style.backgroundSize=[...sizes,'100% 100%'].join(',');
}
