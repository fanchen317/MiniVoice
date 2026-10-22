export function sliderValue(value,min=0,max=1,step=.01){
 min=Number.isFinite(min)?min:0;max=Math.max(min,Number.isFinite(max)?max:min);
 const bounded=Math.max(min,Math.min(max,Number.isFinite(value)?value:min));
 if(!(step>0))return bounded;
 return Math.max(min,Math.min(max,Number((min+Math.round((bounded-min)/step)*step).toFixed(8))));
}
export function sliderAt(clientX,left,width,min,max,step){return sliderValue(min+(max-min)*Math.max(0,Math.min(1,(clientX-left)/Math.max(1,width))),min,max,step);}
export function sliderKey(key,value,min,max,step){
 if(key==='Home')return min;if(key==='End')return max;
 const unit=step>0?step:(max-min)/100,moves={ArrowRight:unit,ArrowUp:unit,ArrowLeft:-unit,ArrowDown:-unit,PageUp:(max-min)/10,PageDown:-(max-min)/10};
 return key in moves?sliderValue(value+moves[key],min,max,step):null;
}
