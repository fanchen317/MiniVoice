import {test} from 'node:test';
import assert from 'node:assert/strict';
import {visualArtworkSubject,artworkFocus} from '../src/components/artworkFocus.js';
const size=96;
function picture(){const data=new Uint8ClampedArray(size*size*4);for(let i=0;i<data.length;i+=4){data[i]=data[i+1]=data[i+2]=235;data[i+3]=255;}return data;}
function block(data,x0,y0,x1,y1,color=[30,70,130]){for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++){let i=(y*size+x)*4;for(let c=0;c<3;c++)data[i+c]=color[c];}}
test('single off-centre silhouette on a uniform background stays whole when it fits',()=>{
 const data=picture();block(data,7,18,30,80);const box=visualArtworkSubject(data,size,size);
 assert.deepEqual(box,{x:7/size,y:18/size,width:23/size,height:62/size});
 const p=artworkFocus(data,size,size,{imageAspect:1,viewportAspect:.3}),left=p.x*.7;
 assert.ok(left<=box.x+1e-8);assert.ok(left+.3>=box.x+box.width-1e-8);
});
test('visual detection rejects complex borders, tiny marks and separated shapes',()=>{
 const texture=picture();block(texture,5,15,30,80);for(let x=0;x<size;x+=2)block(texture,x,0,x+1,2,[0,0,0]);assert.equal(visualArtworkSubject(texture,size,size),null);
 const tiny=picture();block(tiny,8,16,12,20);assert.equal(visualArtworkSubject(tiny,size,size),null);
 const pair=picture();block(pair,8,15,24,75);block(pair,66,15,82,75);assert.equal(visualArtworkSubject(pair,size,size),null);
 assert.equal(visualArtworkSubject(picture(),size,size),null);
});
test('a single silhouette on a smooth gradient remains whole',()=>{
 const data=picture();
 for(let y=0;y<size;y++)for(let x=0;x<size;x++){const i=(y*size+x)*4;data[i]=160+x*.7;data[i+1]=170+y*.6;data[i+2]=160+(x+y)*.3;}
 block(data,7,18,30,80,[25,35,70]);
 const box=visualArtworkSubject(data,size,size);assert.deepEqual(box,{x:7/size,y:18/size,width:23/size,height:62/size});
 const p=artworkFocus(data,size,size,{imageAspect:1,viewportAspect:.3}),left=p.x*.7;
 assert.ok(left<=box.x+1e-8&&left+.3>=box.x+box.width-1e-8);
});
test('a smooth gradient does not merge two separate silhouettes',()=>{
 const data=picture();for(let y=0;y<size;y++)for(let x=0;x<size;x++){const i=(y*size+x)*4;data[i]=160+x*.7;data[i+1]=170+y*.6;data[i+2]=160+(x+y)*.3;}
 block(data,8,15,24,75,[20,20,20]);block(data,66,15,82,75,[20,20,20]);assert.equal(visualArtworkSubject(data,size,size),null);
});
test('visual cue never displaces a detected person or text',()=>{
 const data=picture();block(data,7,18,30,80);
 for(const subject of [{x:.7,y:.3,width:.08,height:.2,face:true,confidence:.9},{x:.68,y:.3,width:.12,height:.2,text:true,confidence:.9}]){
  const p=artworkFocus(data,size,size,{imageAspect:1,viewportAspect:.3,regions:[subject]}),left=p.x*.7;
  assert.ok(left<=subject.x+1e-8);assert.ok(left+.3>=subject.x+subject.width-1e-8);
 }
});
test('a silhouette too wide for the viewport does not force an impossible crop',()=>{
 const data=picture();block(data,5,20,75,76);const box=visualArtworkSubject(data,size,size);assert.ok(box);
 const p=artworkFocus(data,size,size,{imageAspect:1,viewportAspect:.3});assert.ok(Number.isFinite(p.x)&&p.x>=0&&p.x<=1);
});

test('visual cue changes neither semantic detection nor the fallback when it cannot fit',async()=>{
 const {compositionCrop}=await import('../src/components/artworkComposition.js');
 const energy=new Float32Array(16*16).fill(1),options={energy,width:16,height:16};
 const cue={x:.03,y:.15,width:.7,height:.7},face={x:.7,y:.25,width:.1,height:.2,face:true,confidence:.9};
 assert.deepEqual(compositionCrop([face],1,.3,{...options,visualSubject:cue}),compositionCrop([face],1,.3,options));
 assert.deepEqual(compositionCrop([],1,.3,{...options,visualSubject:cue}),compositionCrop([],1,.3,options));
});

test('a title and separate visual subject are both preserved when they fit',()=>{
 const data=picture();block(data,16,18,35,78);block(data,40,80,52,84);
 const title={x:40/size,y:80/size,width:12/size,height:4/size,text:true,confidence:.9};
 const box=visualArtworkSubject(data,size,size);assert.ok(box);
 const p=artworkFocus(data,size,size,{imageAspect:1,viewportAspect:.4,regions:[title]}),left=p.x*.6;
 assert.ok(left<=box.x+1e-8);assert.ok(left+.4>=box.x+box.width-1e-8);
 assert.ok(left<=title.x&&left+.4>=title.x+title.width);
});

test('when title and visual subject cannot fit, title-only behavior is unchanged',async()=>{
 const {compositionCrop}=await import('../src/components/artworkComposition.js');
 const title={x:.7,y:.3,width:.1,height:.1,text:true,confidence:.9},cue={x:.04,y:.2,width:.2,height:.5};
 const energy=new Float32Array(16*16).fill(1),options={energy,width:16,height:16};
 assert.deepEqual(compositionCrop([title],1,.3,{...options,visualSubject:cue}),compositionCrop([title],1,.3,options));
});
