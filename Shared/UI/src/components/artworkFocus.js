// Small thumbnail analysis, once per artwork. No full-resolution canvas allocation.
const cache=new Map();
export function artworkFocus(pixels,width,height){
 let total=0,xTotal=0,yTotal=0;
 for(let y=1;y<height-1;y++)for(let x=1;x<width-1;x++){
  const i=(y*width+x)*4,j=i+4,k=i+width*4;
  const contrast=Math.abs(pixels[i]-pixels[j])+Math.abs(pixels[i+1]-pixels[j+1])+Math.abs(pixels[i+2]-pixels[j+2])+Math.abs(pixels[i]-pixels[k])+Math.abs(pixels[i+1]-pixels[k+1])+Math.abs(pixels[i+2]-pixels[k+2]);
  const nx=x/(width-1),ny=y/(height-1),prior=Math.exp(-((nx-.5)**2+(ny-.43)**2)*5),weight=(contrast+4)*prior;
  total+=weight;xTotal+=nx*weight;yTotal+=ny*weight;
 }
 return total?{x:Math.max(.3,Math.min(.7,xTotal/total)),y:Math.max(.3,Math.min(.65,yTotal/total))}:{x:.5,y:.5};
}
export function applyArtworkFocus(image){
 const key=image.currentSrc||image.src;let focus=cache.get(key);
 if(!focus){try{const canvas=document.createElement('canvas');canvas.width=canvas.height=32;const context=canvas.getContext('2d',{willReadFrequently:true});context.drawImage(image,0,0,32,32);focus=artworkFocus(context.getImageData(0,0,32,32).data,32,32);}catch{focus={x:.5,y:.5};}if(cache.size>=128)cache.delete(cache.keys().next().value);cache.set(key,focus);}
 image.dataset.focalX=String(focus.x);image.dataset.focalY=String(focus.y);image.style.objectPosition=`${focus.x*100}% ${focus.y*100}%`;return focus;
}
