import {test} from 'node:test';
import assert from 'node:assert/strict';
import {artworkFaceRescueCrops,cropArtworkPixels,dedupeArtworkFaces,isolatedArtworkSubject,mapArtworkCropFace,rescueArtworkFaces} from '../src/components/artworkFaceRescue.js';

const person=(x,y,width,height,confidence=.9)=>({x,y,width,height,confidence,person:1});
const face=(x,y,width,height,confidence=.9)=>({x,y,width,height,confidence,face:1});
const pixels=(width,height,value=200)=>new Uint8ClampedArray(width*height*4).fill(value);
test('person crops expand, clip at source edges, suppress duplicates and limit work to two',()=>{
 const boxes=[person(.8,.7,.2,.3,1),person(.81,.71,.19,.29,.9),person(.1,.1,.2,.4,.8),person(.4,.1,.2,.5,.7)];
 const crops=artworkFaceRescueCrops(boxes,100,100);assert.equal(crops.length,2);
 assert.equal(crops[0].left+crops[0].width,100);assert.equal(crops[0].top+crops[0].height,100);
 assert.ok(crops[1].left<10&&crops[1].top<10);
});
test('cropped pixels and normalized face coordinates map back to the original including 1.0',()=>{
 const input=new Uint8ClampedArray(10*10*4);for(let i=0;i<input.length;i++)input[i]=i%256;
 const crop={left:6,top:4,width:4,height:6},part=cropArtworkPixels(input,10,10,crop);
 assert.deepEqual([...part.slice(0,4)],[...input.slice((4*10+6)*4,(4*10+7)*4)]);
 const mapped=mapArtworkCropFace(face(.5,.5,.5,.5),crop,10,10);
 assert.ok(Math.abs(mapped.x-.8)<1e-9&&Math.abs(mapped.y-.7)<1e-9);assert.equal(mapped.x+mapped.width,1);assert.equal(mapped.y+mapped.height,1);
});
test('distinct faces are kept and overlapping results keep the strongest confidence',()=>{
 const found=dedupeArtworkFaces([face(.2,.2,.1,.1,.7),face(.201,.2,.1,.1,.9),face(.7,.2,.1,.1,.8)]);
 assert.equal(found.length,2);assert.equal(found[0].confidence,.9);assert.equal(found[1].confidence,.8);
});
test('only unmatched people get a second pass; already detected faces remain',async()=>{
 const img=pixels(100,100),known=face(.14,.12,.08,.08,.95),people=[person(.1,.12,.18,.5),person(.65,.15,.2,.5)],calls=[];
 const found=await rescueArtworkFaces({faces:[known],people,pixels:img,width:100,height:100,detect:async(data,w,h)=>{calls.push({w,h});return [face(.35,.15,.2,.2,.8)];}});
 assert.equal(calls.length,1);assert.equal(found.length,2);assert.equal(found[0],known);assert.ok(found[1].x>.6);
 const noExtra=await rescueArtworkFaces({faces:[known],people:[people[0]],pixels:img,width:100,height:100,detect:async()=>{throw Error('should not run');}});assert.deepEqual(noExtra,[known]);
});
test('uniform background with one isolated object triggers at most one look; noisy frame does not',async()=>{
 const width=128,height=128,img=pixels(width,height,220);
 for(let y=35;y<90;y++)for(let x=50;x<80;x++)for(let c=0;c<3;c++)img[(y*width+x)*4+c]=30;
 const object=isolatedArtworkSubject(img,width,height);assert.ok(object&&object.x<.4&&object.x+object.width>.6);
 let calls=0;await rescueArtworkFaces({faces:[],people:[],pixels:img,width,height,detect:async()=>{calls++;return [];}});assert.equal(calls,1);
 const noisy=pixels(width,height,220);for(let x=0;x<width;x++)for(let c=0;c<3;c++)noisy[x*4+c]=x%2?0:255;
 assert.equal(isolatedArtworkSubject(noisy,width,height),null);
 calls=0;assert.deepEqual(await rescueArtworkFaces({faces:[],people:[],pixels:noisy,width,height,detect:async()=>{calls++;return [];}}),[]);assert.equal(calls,0);
});
