import test from 'node:test';
import assert from 'node:assert/strict';
import {artworkFaceInput,decodeArtworkFaces,detectArtworkFaces} from '../src/components/artworkFaceDetector.js';

test('face input preserves aspect ratio, pads and uses BGR',()=>{
 const {data,scaledWidth,scaledHeight}=artworkFaceInput(new Uint8Array([10,20,30,255,10,20,30,255]),2,1);
 assert.equal(scaledWidth,640);assert.equal(scaledHeight,320);
 assert.equal(data[0],30);assert.equal(data[640*640],20);assert.equal(data[2*640*640],10);assert.equal(data[320*640],0);
});
test('face decoder maps padded coordinates, retains multiple faces and suppresses duplicates',()=>{
 const outputs={};for(const stride of [8,16,32]){const n=(640/stride)**2;outputs[`cls_${stride}`]={data:new Float32Array(n)};outputs[`obj_${stride}`]={data:new Float32Array(n)};outputs[`bbox_${stride}`]={data:new Float32Array(n*4)};}
 const put=(col,row,score)=>{const i=row*80+col;outputs.cls_8.data[i]=score;outputs.obj_8.data[i]=score;outputs.bbox_8.data[i*4+2]=Math.log(10);outputs.bbox_8.data[i*4+3]=Math.log(10);};
 put(20,20,.9);put(21,20,.8);put(60,20,.85);
 const boxes=decodeArtworkFaces(outputs,640,320);assert.equal(boxes.length,2);assert.ok(Math.abs(boxes[0].x-.1875)<1e-6);assert.ok(Math.abs(boxes[0].y-.375)<1e-6);assert.ok(Math.abs(boxes[0].width-.125)<1e-6);assert.ok(Math.abs(boxes[0].height-.25)<1e-6);
});
test('face detector passes tensor to injected session and returns no invented faces',async()=>{
 class Tensor{constructor(type,data,dims){this.type=type;this.data=data;this.dims=dims;}}
 let input;const session={inputNames:['input'],run:async feeds=>{input=feeds.input;const outputs={};for(const stride of [8,16,32]){const n=(640/stride)**2;for(const type of ['cls','obj'])outputs[`${type}_${stride}`]={data:new Float32Array(n)};outputs[`bbox_${stride}`]={data:new Float32Array(n*4)};}return outputs;}};
 assert.deepEqual(await detectArtworkFaces({ort:{Tensor},session,pixels:new Uint8Array([0,0,0,255]),width:1,height:1}),[]);assert.deepEqual(input.dims,[1,3,640,640]);
});
