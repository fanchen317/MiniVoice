// YuNet 2023mar: BGR 0..255 input, with aspect-preserving right/bottom padding.
// Box decoding follows OpenCV FaceDetectorYN: https://github.com/opencv/opencv/blob/4.x/modules/objdetect/src/face_detect.cpp
const SIZE=640;
const clamp=(v,low,high)=>Math.max(low,Math.min(high,v));

export function artworkFaceInput(pixels,width,height){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||pixels?.length<width*height*4)throw Error('Invalid artwork pixels');
 const scale=Math.min(SIZE/width,SIZE/height),scaledWidth=Math.max(1,Math.round(width*scale)),scaledHeight=Math.max(1,Math.round(height*scale));
 const data=new Float32Array(3*SIZE*SIZE),plane=SIZE*SIZE;
 // Bilinear sampling, matching pixel-centre image resize convention.
 for(let y=0;y<scaledHeight;y++){
  const sy=clamp((y+.5)*height/scaledHeight-.5,0,height-1),y0=Math.floor(sy),y1=Math.min(y0+1,height-1),fy=sy-y0;
  for(let x=0;x<scaledWidth;x++){
   const sx=clamp((x+.5)*width/scaledWidth-.5,0,width-1),x0=Math.floor(sx),x1=Math.min(x0+1,width-1),fx=sx-x0,i=y*SIZE+x;
   for(let ch=0;ch<3;ch++){
    const c=2-ch,a=pixels[(y0*width+x0)*4+c]*(1-fx)+pixels[(y0*width+x1)*4+c]*fx,b=pixels[(y1*width+x0)*4+c]*(1-fx)+pixels[(y1*width+x1)*4+c]*fx;
    data[ch*plane+i]=a*(1-fy)+b*fy;
   }
  }
 }
 return {data,scaledWidth,scaledHeight};
}
function iou(a,b){const w=Math.max(0,Math.min(a.x+a.width,b.x+b.width)-Math.max(a.x,b.x)),h=Math.max(0,Math.min(a.y+a.height,b.y+b.height)-Math.max(a.y,b.y)),intersection=w*h;return intersection/(a.width*a.height+b.width*b.height-intersection||1);}
export function decodeArtworkFaces(outputs,scaledWidth,scaledHeight,{threshold=.6,nms=.3,limit=8}={}){
 const boxes=[];
 for(const stride of [8,16,32]){
  const cls=outputs[`cls_${stride}`]?.data,obj=outputs[`obj_${stride}`]?.data,bbox=outputs[`bbox_${stride}`]?.data,cols=SIZE/stride;
  if(!cls||!obj||!bbox||cls.length<cols*cols||obj.length<cols*cols||bbox.length<cols*cols*4)throw Error('Invalid YuNet outputs');
  for(let i=0;i<cols*cols;i++){
   const confidence=Math.sqrt(clamp(cls[i],0,1)*clamp(obj[i],0,1));if(!(confidence>=threshold))continue;
   const cx=(i%cols+bbox[i*4])*stride,cy=(Math.floor(i/cols)+bbox[i*4+1])*stride,w=Math.exp(bbox[i*4+2])*stride,h=Math.exp(bbox[i*4+3])*stride;
   if(![cx,cy,w,h].every(Number.isFinite))continue;
   const left=clamp((cx-w/2)/scaledWidth,0,1),top=clamp((cy-h/2)/scaledHeight,0,1),right=clamp((cx+w/2)/scaledWidth,0,1),bottom=clamp((cy+h/2)/scaledHeight,0,1);
   if(right>left&&bottom>top)boxes.push({x:left,y:top,width:right-left,height:bottom-top,face:1,confidence});
  }
 }
 boxes.sort((a,b)=>b.confidence-a.confidence);const kept=[];
 for(const box of boxes){if(!kept.some(other=>iou(box,other)>nms))kept.push(box);if(kept.length>=limit)break;}
 return kept;
}
export async function detectArtworkFaces({ort,session,pixels,width,height}){
 const {data,scaledWidth,scaledHeight}=artworkFaceInput(pixels,width,height);
 const tensor=new ort.Tensor('float32',data,[1,3,SIZE,SIZE]);
 const outputs=await session.run({[session.inputNames[0]]:tensor});
 return decodeArtworkFaces(outputs,scaledWidth,scaledHeight);
}
