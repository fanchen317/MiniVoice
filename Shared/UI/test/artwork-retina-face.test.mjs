import {test} from 'node:test';
import assert from 'node:assert/strict';
import {artworkRetinaCandidates,artworkRetinaInput,decodeArtworkRetinaFaces,filterArtworkRetinaFaces} from '../src/components/artworkRetinaFace.js';

test('RetinaFace input preserves aspect and uses BGR mean subtraction',()=>{
 const pixels=new Uint8ClampedArray([200,150,100,255,200,150,100,255]);
 const {data,scaledWidth,scaledHeight}=artworkRetinaInput(pixels,2,1);
 assert.equal(scaledWidth,640);assert.equal(scaledHeight,320);
 assert.equal(data[0],-4);assert.equal(data[640*640],33);assert.equal(data[2*640*640],77);
 assert.equal(data[639*640],-104,'padded pixels use a black background');
});

test('RetinaFace decodes anchors, clips padding and suppresses duplicates',()=>{
 const count=2*(80*80+40*40+20*20),loc=new Float32Array(count*4),conf=new Float32Array(count*2),i=(10*80+10)*2;
 conf[i*2+1]=.96;conf[(i+1)*2+1]=.93;
 loc[(i+1)*4+2]=loc[(i+1)*4+3]=Math.log(.5)/.2;
 const boxes=decodeArtworkRetinaFaces({loc:{data:loc},conf:{data:conf}},640,320);
 assert.equal(boxes.length,1);assert.ok(Math.abs(boxes[0].x-76/640)<1e-6);assert.ok(Math.abs(boxes[0].y-76/320)<1e-6);
 assert.ok(Math.abs(boxes[0].width-16/640)<1e-6);assert.ok(Math.abs(boxes[0].height-16/320)<1e-6);
 assert.throws(()=>decodeArtworkRetinaFaces({loc:{data:loc},conf:{data:new Float32Array(1)}},640,640),/Invalid/);
});

test('the fallback keeps only unmatched people and faces supported by them',()=>{
 const person={x:.2,y:.25,width:.3,height:.6,person:1,confidence:.9};
 const weak={...person,confidence:.2},face={x:.3,y:.2,width:.1,height:.1,face:1,confidence:.95};
 assert.deepEqual(artworkRetinaCandidates([], [person,weak]),[person]);
 assert.deepEqual(artworkRetinaCandidates([face],[person]),[]);
 const other={...person,x:.65,width:.25};
 assert.deepEqual(artworkRetinaCandidates([face],[person,other]),[other]);
 assert.deepEqual(artworkRetinaCandidates([],[]),[]);
 const unrelated={...face,x:.85};
 assert.deepEqual(filterArtworkRetinaFaces([face,unrelated],[person]),[face]);
});
