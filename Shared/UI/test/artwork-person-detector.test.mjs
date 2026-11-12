import test from 'node:test';
import assert from 'node:assert/strict';
import {artworkPersonInput,decodeArtworkPeople,detectArtworkPeople} from '../src/components/artworkPersonDetector.js';

test('person input preserves aspect, BGR channels and the model padding',()=>{
 const {data,ratio}=artworkPersonInput(new Uint8Array([10,20,30,255,10,20,30,255]),2,1);
 assert.equal(ratio,208);assert.equal(data[0],30);assert.equal(data[416*416],20);assert.equal(data[2*416*416],10);assert.equal(data[208*416],114);
});
test('person decoder retains separate people, suppresses duplicates and ignores other classes',()=>{
 const data=new Float32Array(3549*85),put=(col,row,score)=>{const p=(row*52+col)*85;data[p]=.5;data[p+1]=.5;data[p+2]=Math.log(3);data[p+3]=Math.log(6);data[p+4]=score;data[p+5]=1;};
 put(10,10,.9);put(11,10,.8);put(35,25,.7);data[85*5+4]=1;data[85*5+6]=1;
 const boxes=decodeArtworkPeople({data},416,416,1);assert.equal(boxes.length,2);assert.ok(boxes[0].x<boxes[1].x);assert.ok(boxes.every(b=>b.person===1&&b.x>=0&&b.y>=0&&b.x+b.width<=1&&b.y+b.height<=1));
});
test('person detector passes expected tensor and returns no invented subjects',async()=>{
 class Tensor{constructor(type,data,dims){this.type=type;this.data=data;this.dims=dims;}}
 let input;const session={inputNames:['images'],outputNames:['output'],run:async feeds=>{input=feeds.images;return {output:{data:new Float32Array(3549*85)}};}};
 assert.deepEqual(await detectArtworkPeople({ort:{Tensor},session,pixels:new Uint8Array([0,0,0,255]),width:1,height:1}),[]);assert.deepEqual(input.dims,[1,3,416,416]);
});
