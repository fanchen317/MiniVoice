export function fragmentProgress(elapsed,center,origin,size){
  const delay=Math.min(1,Math.hypot(center.x-origin.x,center.y-origin.y)/Math.max(1,Math.hypot(size.width,size.height)))*200;
  return Math.min(1,Math.max(0,(elapsed-delay)/480));
}
export function fragmentCells(width,height,maxCells=224){
  if(width<=0||height<=0)return[];
  let columns=Math.max(6,Math.min(16,Math.ceil(width/72))),rows=Math.max(6,Math.min(14,Math.ceil(height/72)));
  while(columns*rows>maxCells){if(columns>=rows&&columns>1)columns--;else if(rows>1)rows--;else break;}
  return Array.from({length:rows*columns},(_,i)=>({x:i%columns*width/columns,y:Math.floor(i/columns)*height/rows,width:width/columns,height:height/rows}));
}

export function prepareFragments(width,height,origin,options={}){
 return fragmentCells(width,height,options.maxCells).map((cell,index)=>{const center={x:cell.x+cell.width/2,y:cell.y+cell.height/2},angle=Math.atan2(center.y-origin.y,center.x-origin.x);return {...cell,center,index,cos:Math.cos(angle),sin:Math.sin(angle),delay:Math.min(1,Math.hypot(center.x-origin.x,center.y-origin.y)/Math.max(1,Math.hypot(width,height)))*200};});
}
export function paintFragments(context,bitmap,width,height,origin,elapsed,plan=prepareFragments(width,height,origin)){
 for(const cell of plan){
  const {center,index}=cell,p=Math.min(1,Math.max(0,(elapsed-cell.delay)/480));if(p>=1)continue;
  const eased=p*p*(3-2*p),curl=Math.sin(p*Math.PI)*(index%7-3)*6,distance=eased*140;
  context.save();context.globalAlpha=1-eased;
  context.translate(center.x+cell.cos*distance-cell.sin*curl,center.y+cell.sin*distance+cell.cos*curl);
  context.rotate((index%9-4)*eased*8*Math.PI/180);context.scale(1-eased*.65,1-eased*.65);
  context.drawImage(bitmap,cell.x/width*bitmap.width,cell.y/height*bitmap.height,cell.width/width*bitmap.width,cell.height/height*bitmap.height,-cell.width/2,-cell.height/2,cell.width,cell.height);context.restore();
 }
}

/** Samples the same curl as paintFragments; only transform/opacity animate. */
export function fragmentKeyframes(cell){
 return Array.from({length:17},(_,i)=>{const p=i/16,eased=p*p*(3-2*p),curl=Math.sin(p*Math.PI)*(cell.index%7-3)*6,distance=eased*140;return {offset:p,opacity:1-eased,transform:`translate(${cell.cos*distance-cell.sin*curl}px,${cell.sin*distance+cell.cos*curl}px) rotate(${(cell.index%9-4)*eased*8}deg) scale(${1-eased*.65})`};});
}
