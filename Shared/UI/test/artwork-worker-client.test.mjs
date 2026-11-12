import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createArtworkWorkerClient} from '../src/artworkWorkerClient.js';
function fixture(){
 const workers=[];
 const client=createArtworkWorkerClient(()=>{const worker={postMessage(message,transfer){this.message=message;this.transfer=transfer;},terminate(){this.stopped=true;}};workers.push(worker);return worker;},{timeoutMs:25});
 return {client,workers};
}
const pixels=()=>({pixels:new Uint8ClampedArray(16),width:2,height:2});
test('reuses one worker and transfers image pixels to it',async()=>{
 const {client,workers}=fixture(),image=pixels(),buffer=image.pixels.buffer,pending=client.analyze(image),worker=workers[0];
 assert.deepEqual(worker.transfer,[buffer]);assert.equal(worker.message.width,2);
 const regions=[{face:1,x:.5,y:.2,width:.2,height:.2}];worker.onmessage({data:{id:worker.message.id,regions}});
 assert.deepEqual(await pending,regions);
 const next=client.analyze(pixels());assert.equal(workers.length,1);worker.onmessage({data:{id:worker.message.id,regions:[]}});assert.deepEqual(await next,[]);client.dispose();
});
test('worker errors reject pending work and next request gets a new worker',async()=>{
 const {client,workers}=fixture(),first=client.analyze(pixels());workers[0].onerror();
 await assert.rejects(first,/worker failed/);assert.equal(workers[0].stopped,true);
 const retry=client.analyze(pixels()),fresh=workers[1];fresh.onmessage({data:{id:fresh.message.id,regions:[]}});assert.deepEqual(await retry,[]);client.dispose();
});
test('timeout terminates unresponsive worker and retry is possible',async()=>{
 const {client,workers}=fixture(),first=client.analyze(pixels());await assert.rejects(first,/timed out/);assert.equal(workers[0].stopped,true);
 const retry=client.analyze(pixels()),fresh=workers[1];fresh.onmessage({data:{id:fresh.message.id,regions:[]}});assert.deepEqual(await retry,[]);client.dispose();
});
test('detector errors and malformed replies are not cached as successful results',async()=>{
 const {client,workers}=fixture(),first=client.analyze(pixels());workers[0].onmessage({data:{id:workers[0].message.id,error:'model unavailable'}});await assert.rejects(first,/model unavailable/);
 assert.equal(workers[0].stopped,true);const second=client.analyze(pixels());workers[1].onmessage({data:{id:workers[1].message.id}});await assert.rejects(second,/Invalid artwork worker response/);assert.equal(workers[1].stopped,true);client.dispose();
});
