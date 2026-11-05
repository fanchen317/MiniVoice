import {test} from 'node:test';
import assert from 'node:assert/strict';
import {compositionCrop} from '../src/components/artworkComposition.js';
import {applyArtworkFocus,warmArtworkSubjects} from '../src/components/artworkFocus.js';
const face={x:.2,y:.32,width:.15,height:.1,face:1,confidence:.9};
const header={x:0,y:0,width:1,height:.45,weight:1};

test('final background dimensions override an unrelated window or animation aspect',()=>{
 const target={width:2000,height:1000};
 const result=compositionCrop([face],1,.4,{viewport:target});
 assert.deepEqual(result,compositionCrop([face],1,2));
 assert.notDeepEqual(result,compositionCrop([face],1,.4));
});

test('candidate crop puts a feasible face beside an overlay without clipping hair',()=>{
 const baseline=compositionCrop([face],1,2),result=compositionCrop([face],1,2,{viewport:{width:2000,height:1000,occlusions:[header]}});
 const top=result.y*.5,visibleY=(face.y-top)/.5;
 assert.ok(visibleY>=header.height-.01,'face should not be behind the header');
 assert.ok(top<=face.y-face.height*.65+1e-8,'hair padding must stay in frame');
 assert.ok(top+.5>=face.y+face.height*1.2-1e-8);
 assert.ok(result.y<baseline.y);
});

test('overlapping controls are not counted twice and unrelated subjects are order independent',()=>{
 const viewport={width:2000,height:1000,occlusions:[header]};
 assert.deepEqual(compositionCrop([face],1,2,{viewport}),compositionCrop([face],1,2,{viewport:{...viewport,occlusions:[header,header]}}));
 const people=[{x:.1,y:.1,width:.14,height:.13,face:1,confidence:.8},{x:.1,y:.7,width:.14,height:.13,face:1,confidence:.8}];
 assert.deepEqual(compositionCrop(people,1,2,{viewport}),compositionCrop([...people].reverse(),1,2,{viewport}));
});

test('raw original and trimmed preview do not share a pixel coordinate cache',async()=>{
 const previous=globalThis.document,key='minivoice-art://cover/crop-space-test?v=1';let samples=0;
 const pixels=new Uint8ClampedArray(32*32*4);
 globalThis.document={createElement:()=>({getContext:()=>({drawImage:()=>samples++,getImageData:()=>({data:pixels,width:32,height:32})})})};
 try{
  await warmArtworkSubjects(key,async()=>[{x:.75,y:.2,width:.12,height:.2,face:1}]);
  const image=(width,height)=>({src:key,naturalWidth:width,naturalHeight:height,style:{},dataset:{}});
  const preview=applyArtworkFocus(image(320,320),{key,viewport:{width:500,height:1000},coordinateSpace:'preview'});
  const original=applyArtworkFocus(image(640,640),{key,viewport:{width:500,height:1000},coordinateSpace:'original'});
  assert.ok(original.x>.75);assert.ok(Math.abs(preview.x-.5)<.02);assert.equal(samples,2);
  assert.deepEqual(applyArtworkFocus(image(320,320),{key,viewport:{width:500,height:1000},coordinateSpace:'preview'}),preview);
  assert.equal(samples,2,'late preview must reuse its own sample instead of replacing the original');
  applyArtworkFocus(image(1200,1200),{key,viewport:{width:500,height:1000},coordinateSpace:'original'});
  assert.equal(samples,3,'a higher-resolution original must resample');
 }finally{globalThis.document=previous;}
});

test('same-aspect targets with different overlays have separate cached compositions',async()=>{
 const previous=globalThis.document,key='minivoice-art://cover/crop-overlay-test?v=1';
 const pixels=new Uint8ClampedArray(32*32*4);
 globalThis.document={createElement:()=>({getContext:()=>({drawImage:()=>{},getImageData:()=>({data:pixels,width:32,height:32})})})};
 try{await warmArtworkSubjects(key,async()=>[face]);const image={src:key,naturalWidth:640,naturalHeight:640,style:{},dataset:{}};
  const clear=applyArtworkFocus(image,{key,coordinateSpace:'original',viewport:{width:2000,height:1000}});
  const covered=applyArtworkFocus(image,{key,coordinateSpace:'original',viewport:{width:2000,height:1000,occlusions:[header]}});
  assert.ok(covered.y<clear.y);assert.deepEqual(applyArtworkFocus(image,{key,coordinateSpace:'original',viewport:{width:2000,height:1000}}),clear);
 }finally{globalThis.document=previous;}
});

test('a larger analysis request queues one bounded quality upgrade after in-flight preview analysis',async()=>{
 const key='test://quality-upgrade',seen=[];let release;
 const first=warmArtworkSubjects(key,context=>{seen.push(context);return new Promise(resolve=>{release=resolve;});});
 await Promise.resolve();
 const context={width:3440,height:1440,pixelRatio:1};
 const upgrade=warmArtworkSubjects(key,async value=>{seen.push(value);return [face];},context);
 const duplicate=warmArtworkSubjects(key,async()=>{throw Error('duplicate analysis');},context);
 release([]);await Promise.all([first,upgrade,duplicate]);
 assert.equal(seen.length,2);assert.equal(seen[0],undefined);assert.equal(seen[1],context);
 await warmArtworkSubjects(key,()=>{throw Error('quality should already be sufficient');},{width:3600,height:1440});
 assert.equal(seen.length,2,'nearby sizes within the same quality bucket must not re-run recognition');
});

test('multiscale visual fallback keeps a broad off-centre object instead of a narrow noisy stripe',async()=>{
 const {artworkFocus}=await import('../src/components/artworkFocus.js'),n=96,pixels=new Uint8ClampedArray(n*n*4);
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){
  const at=(y*n+x)*4;pixels[at]=pixels[at+1]=pixels[at+2]=40;pixels[at+3]=255;
  if(x>=4&&x<22&&y>=18&&y<78){pixels[at]=190;pixels[at+1]=125;pixels[at+2]=90;}
  if(x>60&&x<70&&y>10&&y<86){const value=40+((x+y)%2?90:0);pixels[at]=pixels[at+1]=pixels[at+2]=value;}
 }
 const result=artworkFocus(pixels,n,n,{viewport:{width:600,height:2000}}),left=result.x*.7;
 assert.ok(left<=4/n);assert.ok(left+.3>=22/n);
 const blue=pixels.slice();for(let i=0;i<blue.length;i+=4){blue[i]=pixels[i+2];blue[i+2]=pixels[i];}
 assert.deepEqual(artworkFocus(blue,n,n,{viewport:{width:600,height:2000}}),result,'hue permutation must not be interpreted as a different person');
});

test('invalid masks and detector boxes cannot produce nonfinite focal positions',()=>{
 const malformed=[null,{x:NaN,y:0,width:.2,height:.2},{x:-2,y:.2,width:.1,height:.1},{x:.1,y:.2,width:.2,height:.2,face:1,confidence:NaN}].filter(Boolean);
 for(const viewport of [{width:0,height:0,occlusions:'invalid'},{width:1080,height:1920,occlusions:[{x:NaN,y:0,width:1,height:1}]},{width:3440,height:1440,occlusions:[{x:-1,y:-1,width:3,height:3,weight:Infinity}]}]){
  const result=compositionCrop(malformed,1,1.7,{viewport});assert.ok(Number.isFinite(result.x)&&Number.isFinite(result.y));assert.ok(result.x>=0&&result.x<=1&&result.y>=0&&result.y<=1);
 }
});
