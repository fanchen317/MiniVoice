const clamp=(value,min,max)=>Math.max(min,Math.min(max,Number.isFinite(value)?value:0));
export function scrollMetrics(viewport,content,position,{minimum=36,maximum=72}={}){
 viewport=Math.max(0,viewport);content=Math.max(viewport,content);
 const range=content-viewport,height=Math.min(viewport,clamp(viewport*viewport/Math.max(1,content),minimum,maximum)),travel=Math.max(0,viewport-height);
 return {viewport,content,range,height,travel,position:clamp(position,0,range),top:range?clamp(position,0,range)/range*travel:0,overflow:range>1};
}
export function dragPosition(start,delta,metric){return metric.travel?clamp(start+delta/metric.travel*metric.range,0,metric.range):0;}
export function keyboardPosition(key,position,metric){
 const moves={ArrowDown:40,ArrowUp:-40,PageDown:metric.viewport*.9,PageUp:-metric.viewport*.9};
 if(key==='Home')return 0;if(key==='End')return metric.range;
 return key in moves?clamp(position+moves[key],0,metric.range):null;
}
