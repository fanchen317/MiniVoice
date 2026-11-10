import test from 'node:test';
import assert from 'node:assert/strict';
import {createArtworkPreloader} from '../src/artworkPreloader.js';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
function loader(){const started=[],tasks=new Map();return {started,tasks,load:source=>{started.push(source);return new Promise((resolve,reject)=>tasks.set(source,{resolve,reject}));}};}
const image=(width=10,height=10)=>({naturalWidth:width,naturalHeight:height});
test('speculative cover decoding bounds concurrency, shares work and drops obsolete queued destinations',async()=>{
 const fake=loader(),preload=createArtworkPreloader({load:fake.load,concurrency:2});let old=true;
 const first=preload.prefetch(['a','b','c','d'],()=>old);await turn();assert.deepEqual(fake.started,['a','b']);
 old=false;const second=preload.prefetch(['b','e']);await turn();assert.equal(preload.stats().queued,1);
 fake.tasks.get('a').resolve(image());fake.tasks.get('b').resolve(image());await turn();assert.deepEqual(fake.started,['a','b','e']);
 fake.tasks.get('e').resolve(image());assert.deepEqual(await second,[true,true]);assert.deepEqual(await first,[false,false,false,false]);
 assert.equal(preload.stats().entries,2);assert.equal(preload.stats().active,0);
});
test('decoded working set evicts by bytes and recency; large originals and failures are not retained',async()=>{
 const calls=[],preload=createArtworkPreloader({maxBytes:800,maxEntries:3,load:async source=>{calls.push(source);if(source==='fail')throw Error('missing');return source==='large'?image(2000,2000):image();}});
 await preload.prefetch(['a','b']);await preload.prefetch(['a']);await preload.prefetch(['c']);
 assert.equal(preload.stats().bytes,800);assert.equal(preload.stats().entries,2);
 await preload.prefetch(['a']);assert.deepEqual(calls,['a','b','c']);
 await preload.prefetch(['b']);assert.deepEqual(calls,['a','b','c','b']);
 await preload.prefetch(['large','large','fail']);await preload.prefetch(['large','fail']);
 assert.equal(calls.filter(source=>source==='large').length,2);assert.equal(calls.filter(source=>source==='fail').length,2);
 assert.ok(preload.stats().bytes<=800);preload.dispose();assert.equal(preload.stats().entries,0);
});
test('leaving the wall settles queued requests and cannot repopulate its decoded cache',async()=>{
 const fake=loader(),preload=createArtworkPreloader({load:fake.load,concurrency:1}),work=preload.prefetch(['a','b','c']);await turn();preload.dispose();fake.tasks.get('a').resolve(image());
 assert.deepEqual(await work,[false,false,false]);assert.deepEqual(fake.started,['a']);assert.equal(preload.stats().entries,0);
 assert.deepEqual(await preload.prefetch(['d']),[]);
});
test('foreground artwork jumps ahead of speculative neighbours without duplicating an active load',async()=>{
 const fake=loader(),preload=createArtworkPreloader({load:fake.load,concurrency:1});
 const background=preload.prefetch(['a','b','c']);await turn();
 const focus=preload.prefetch(['c'],()=>true,{priority:true});
 fake.tasks.get('a').resolve(image());await turn();assert.deepEqual(fake.started,['a','c']);
 fake.tasks.get('c').resolve(image());assert.deepEqual(await focus,[true]);await turn();
 fake.tasks.get('b').resolve(image());assert.deepEqual(await background,[true,true,true]);preload.dispose();
});
test('a non-retained result can be retried immediately from its completion callback',async()=>{
 let calls=0;const preload=createArtworkPreloader({load:async()=>{calls++;return image(2000,2000);},maxBytes:100});
 await preload.prefetch(['large']).then(()=>preload.prefetch(['large']));
 assert.equal(calls,2);preload.dispose();
});
