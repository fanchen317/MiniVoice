// Numerical values mirror MiniVoice's native transitions. These helpers are
// independent of display rate and are also used by deterministic motion tests.
export function springProgress(elapsed, response=.46, damping=.9) {
  const t=Math.max(0,elapsed)/1000, w=2*Math.PI/response;
  if(damping>=1)return 1-(1+w*t)*Math.exp(-w*t);
  const wd=w*Math.sqrt(1-damping*damping);
  return 1-Math.exp(-damping*w*t)*(Math.cos(wd*t)+damping*w/wd*Math.sin(wd*t));
}
export function springEasing(response=.46,damping=.9,duration=600){
  return `linear(${Array.from({length:61},(_,i)=>`${(i===60?1:springProgress(i/60*duration,response,damping)).toFixed(5)} ${(i/60*100).toFixed(2)}%`).join(',')})`;
}
export {fragmentCells,fragmentProgress} from '../../../Shared/UI/src/fragmentMotion.js';
export function playerDetailMetrics({width,height,controls}){
  const panelHeight=height-46,budget=panelHeight-38-controls-12*3-150;
  const artworkSize=Math.max(88,Math.min(260,width*.34,panelHeight*.23,budget));
  return {artworkSize,titleSize:artworkSize<160?20:artworkSize<180?23:30,artworkRadius:Math.min(22,artworkSize*.16)};
}
export function wallDockMetrics(width){
  const p=Math.min(1,Math.max(0,(width-340)/100)),detail=p*p*(3-2*p);
  return {detail,spacing:8+4*detail,padding:12+4*detail,playSide:40+6*detail,playFont:24+2*detail};
}

export function browseGridMetrics(panelWidth,artist){
  const available=Math.max(1,panelWidth-56),columns=Math.max(1,Math.floor((available+16)/152)),width=Math.max(1,(available-(columns-1)*16)/columns),compact=columns===1;
  const artwork=compact?54:Math.min(width-16,artist?104:120);
  const height=compact?70:artwork+4+32+14+(artist?12:32)+16;
  return {columns,width,compact,artwork,height,stride:height+(compact?4:16),available};
}

// Counteract the card's FLIP stretch on artwork alone. Covers keep their
// intrinsic aspect ratio and continue to fill the animated clipping rectangle.
export function posterArtworkMotion(from,to,ratio,progressAt,samples=53){
  ratio=Number.isFinite(ratio)&&ratio>0?ratio:1;
  const width=Math.max(to.width,to.height*ratio),height=width/ratio;
  const frames=Array.from({length:samples},(_,index)=>{
    const offset=index/(samples-1),p=progressAt(offset),sx=(from.width+(to.width-from.width)*p)/to.width,sy=(from.height+(to.height-from.height)*p)/to.height;
    const fill=Math.max(to.width*sx/width,to.height*sy/height);
    return {offset,transform:`translate(-50%,-50%) scale(${fill/sx},${fill/sy})`};
  });
  return {width,height,frames};
}

// Center the expanded dock in the wall's available region. Lift tools only
// when their bottom-right hit target would collide with that dock plus a gap.
export function wallDockPlacement(width,leadingInset,dockWidth){
  const left=(width+leadingInset-dockWidth)/2;
  return {left,toolsBottom:left+dockWidth+12>width-16-38?94:18};
}
