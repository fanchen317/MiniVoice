import test from 'node:test';
import assert from 'node:assert/strict';
import {textDetectorInput,textProbabilityRegions,detectArtworkText} from '../src/components/artworkTextDetector.js';

test('input uses BGR channels, normalizes and preserves aligned dimensions',()=>{
 const rgba=new Uint8Array(32*32*4);for(let i=0;i<rgba.length;i+=4){rgba[i]=255;rgba[i+3]=255;}
 const p=textDetectorInput(rgba,32,32);assert.equal(p.width,32);assert.equal(p.height,32);
 assert.ok(Math.abs(p.data[0]-(0-.485)/.229)<1e-5);
 assert.ok(Math.abs(p.data[2*1024]-(1-.406)/.225)<1e-5);
});

test('probability map extracts bounded text regions and rejects weak noise',()=>{
 const data=new Float32Array(32*32);for(let y=10;y<14;y++)for(let x=5;x<22;x++)data[y*32+x]=.9;data[2]=1;
 const regions=textProbabilityRegions(data,32,32);assert.equal(regions.length,1);const b=regions[0];assert.equal(b.text,1);assert.ok(b.x<5/32&&b.x+b.width>22/32);assert.ok(b.y<10/32&&b.y+b.height>14/32);assert.ok(b.confidence>.89);
});

test('detector supplies model tensor and consumes the named output',async()=>{
 const rgba=new Uint8Array(32*32*4);const ort={Tensor:class{constructor(type,data,dims){Object.assign(this,{type,data,dims});}}};
 const session={inputNames:['x'],outputNames:['map'],async run(inputs){assert.deepEqual(inputs.x.dims,[1,3,32,32]);let data=new Float32Array(32*32);for(let y=4;y<8;y++)for(let x=5;x<13;x++)data[y*32+x]=.9;return {map:{data,dims:[1,1,32,32]}};}};
 assert.equal((await detectArtworkText({rgba,width:32,height:32,session,ort})).length,1);
});
