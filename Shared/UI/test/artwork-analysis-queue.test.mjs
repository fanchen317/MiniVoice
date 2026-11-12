import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createLatestFirstQueue} from '../src/artworkAnalysisQueue.js';

test('the newest waiting selection runs first without abandoning an in-flight image',async()=>{
 const enqueue=createLatestFirstQueue(),order=[];let release;
 const first=enqueue(()=>new Promise(resolve=>{order.push('A');release=resolve;}));
 const second=enqueue(async()=>{order.push('B');return 'B';});
 const latest=enqueue(async()=>{order.push('C');return 'C';});
 release('A');assert.deepEqual(await Promise.all([first,second,latest]),['A','B','C']);
 assert.deepEqual(order,['A','C','B']);
});
test('a failed analysis does not block later selections',async()=>{
 const enqueue=createLatestFirstQueue();
 const failed=enqueue(async()=>{throw Error('broken image');});
 const next=enqueue(async()=>42);
 await assert.rejects(failed,/broken image/);assert.equal(await next,42);
});
test('returning to an in-flight cover joins its original analysis',async()=>{
 const {warmArtworkSubjects}=await import('../src/components/artworkFocus.js');
 const enqueue=createLatestFirstQueue();let release,calls=0;
 const read=()=>{calls++;return enqueue(()=>new Promise(resolve=>{release=resolve;}));};
 const first=warmArtworkSubjects('test://queue-return-a',read);
 await Promise.resolve();
 const returned=warmArtworkSubjects('test://queue-return-a',read);
 release([{x:.1,y:.2,width:.1,height:.2,face:1}]);
 assert.deepEqual(await returned,await first);assert.equal(calls,1);
});
test('focused images outrank queued background indexing and can promote a shared request',async()=>{
 const enqueue=createLatestFirstQueue(),order=[];let release;
 const active=enqueue(()=>new Promise(resolve=>{order.push('active');release=resolve;}),{priority:'background'});
 const shared=enqueue(async()=>{order.push('shared');return 1;},{priority:'background'});
 const speculative=enqueue(async()=>{order.push('other');return 2;},{priority:'background'});
 shared.promote();release();await Promise.all([active,shared,speculative]);
 assert.deepEqual(order,['active','shared','other']);
});
