// YOLOX-Nano COCO: BGR 0..255, left/top aligned, padding 114.
// See https://github.com/Megvii-BaseDetection/YOLOX/tree/main/demo/ONNXRuntime
const SIZE=416, CHANNELS=85, COUNT=3549;
const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));

export function artworkPersonInput(pixels,width,height){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||pixels?.length<width*height*4)throw Error('Invalid artwork pixels');
 const ratio=Math.min(SIZE/width,SIZE/height),scaledWidth=Math.max(1,Math.floor(width*ratio)),scaledHeight=Math.max(1,Math.floor(height*ratio));
 const data=new Float32Array(3*SIZE*SIZE),plane=SIZE*SIZE;data.fill(114);
 for(let y=0;y<scaledHeight;y++){
  const sy=clamp((y+.5)*height/scaledHeight-.5,0,height-1),y0=Math.floor(sy),y1=Math.min(y0+1,height-1),fy=sy-y0;
  for(let x=0;x<scaledWidth;x++){
   const sx=clamp((x+.5)*width/scaledWidth-.5,0,width-1),x0=Math.floor(sx),x1=Math.min(x0+1,width-1),fx=sx-x0,i=y*SIZE+x;
   for(let ch=0;ch<3;ch++){
    const c=2-ch,a=pixels[(y0*width+x0)*4+c]*(1-fx)+pixels[(y0*width+x1)*4+c]*fx,b=pixels[(y1*width+x0)*4+c]*(1-fx)+pixels[(y1*width+x1)*4+c]*fx;
    data[ch*plane+i]=Math.round(a*(1-fy)+b*fy);
   }
  }
 }
 return {data,ratio,width,height};
}
function iou(a,b){const w=Math.max(0,Math.min(a.x+a.width,b.x+b.width)-Math.max(a.x,b.x)),h=Math.max(0,Math.min(a.y+a.height,b.y+b.height)-Math.max(a.y,b.y)),intersection=w*h;return intersection/(a.width*a.height+b.width*b.height-intersection||1);}
export function decodeArtworkPeople(output,width,height,ratio,{threshold=.3,nms=.45,limit=8}={}){
 const data=output?.data;if(!data||data.length!==COUNT*CHANNELS||!(width>0&&height>0&&ratio>0))throw Error('Invalid YOLOX outputs');
 const boxes=[];let index=0;
 for(const stride of [8,16,32])for(let row=0;row<SIZE/stride;row++)for(let col=0;col<SIZE/stride;col++,index++){
  const p=index*CHANNELS,confidence=data[p+4]*data[p+5];if(!Number.isFinite(confidence)||confidence<threshold)continue;
  const cx=(data[p]+col)*stride/ratio,cy=(data[p+1]+row)*stride/ratio,w=Math.exp(data[p+2])*stride/ratio,h=Math.exp(data[p+3])*stride/ratio;
  if(![cx,cy,w,h].every(Number.isFinite))continue;
  const left=clamp((cx-w/2)/width,0,1),top=clamp((cy-h/2)/height,0,1),right=clamp((cx+w/2)/width,0,1),bottom=clamp((cy+h/2)/height,0,1);
  if(right>left&&bottom>top)boxes.push({x:left,y:top,width:right-left,height:bottom-top,person:1,confidence:clamp(confidence,0,1)});
 }
 boxes.sort((a,b)=>b.confidence-a.confidence);const kept=[];
 for(const box of boxes){if(!kept.some(other=>iou(box,other)>nms))kept.push(box);if(kept.length>=limit)break;}
 return kept;
}
export async function detectArtworkPeople({ort,session,pixels,width,height}){
 const {data,ratio}=artworkPersonInput(pixels,width,height);
 const outputs=await session.run({[session.inputNames[0]]:new ort.Tensor('float32',data,[1,3,SIZE,SIZE])});
 return decodeArtworkPeople(outputs[session.outputNames[0]],width,height,ratio);
}
