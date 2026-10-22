export function menuIndex(enabled,index,key){
 const available=enabled.flatMap((value,i)=>value?[i]:[]);if(!available.length)return -1;
 if(key==='Home')return available[0];if(key==='End')return available.at(-1);
 const direction=key==='ArrowDown'?1:key==='ArrowUp'?-1:0;if(!direction)return index;
 const current=available.indexOf(index);return available[(current<0?(direction>0?0:available.length-1):(current+direction+available.length)%available.length)];
}
export function menuMatch(labels,enabled,query,start=-1){
 const normalize=value=>String(value).normalize('NFKC').toLocaleLowerCase().trim();query=normalize(query);if(!query)return -1;
 for(let offset=1;offset<=labels.length;offset++){const index=(Math.max(-1,start)+offset)%labels.length;if(enabled[index]&&normalize(labels[index]).startsWith(query))return index;}return -1;
}
export function menuPosition(point,panel,viewport,padding=8){
 const width=Math.max(0,Math.min(panel.width,viewport.width-padding*2)),height=Math.max(0,Math.min(panel.height,viewport.height-padding*2));
 return {left:Math.max(padding,Math.min(point.x,viewport.width-width-padding)),top:Math.max(padding,Math.min(point.y,viewport.height-height-padding)),maxWidth:Math.max(0,viewport.width-padding*2),maxHeight:Math.max(0,viewport.height-padding*2)};
}
