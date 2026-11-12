import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createArtworkIndexer,mobileArtworkCandidate,desktopArtworkCandidate} from '../src/artworkIndexing.js';
const flush=async()=>{for(let i=0;i<5;i++)await Promise.resolve();};
test('background indexing waits for idle, deduplicates and stops when hidden',async()=>{
 let time=0,visible=true,id=0;const timers=new Map(),seen=[];
 const indexer=createArtworkIndexer({run:async item=>{seen.push(item.identity);return true;},isVisible:()=>visible,now:()=>time,setTimer:(fn,ms)=>{timers.set(++id,{fn,at:time+ms});return id;},clearTimer:key=>timers.delete(key),interval:100});
 const advance=async(ms)=>{time+=ms;for(const [key,timer] of [...timers])if(timer.at<=time){timers.delete(key);timer.fn();}await flush();};
 indexer.update([{source:'a',identity:'a'},{source:'same',identity:'a'},{source:'b',identity:'b'}]);
 await advance(80);assert.deepEqual(seen,[]);indexer.activity();await advance(90);assert.deepEqual(seen,[]);await advance(10);assert.deepEqual(seen,['a']);
 visible=false;indexer.visibilityChanged();await advance(200);assert.deepEqual(seen,['a']);visible=true;indexer.visibilityChanged();await advance(0);assert.deepEqual(seen,['a','b']);
 indexer.update([{source:'a',identity:'a'},{source:'b',identity:'b'}]);await advance(200);assert.deepEqual(seen,['a','b']);indexer.dispose();
});
test('unavailable persistent storage stops speculative work',async()=>{
 let task;const seen=[];const indexer=createArtworkIndexer({run:async item=>{seen.push(item.identity);return false;},now:()=>100,setTimer:fn=>{task=fn;return 1;},clearTimer:()=>{},interval:0});
 indexer.update([{source:'a',identity:'a'},{source:'b',identity:'b'}]);task();await flush();assert.deepEqual(seen,['a']);indexer.dispose();
});
test('stable artwork versions distinguish changed images and ignore transient URLs',()=>{
 const a=mobileArtworkCandidate({id:'42',artworkRevision:'v1',artworkDetail:'art?e=1'},'Android');
 const b=mobileArtworkCandidate({id:'42',artworkRevision:'v1',artworkDetail:'art?e=2'},'Android');
 assert.equal(a.identity,b.identity);assert.notEqual(a.identity,mobileArtworkCandidate({id:'42',artworkRevision:'v2',artworkDetail:'art'},'Android').identity);
 assert.equal(mobileArtworkCandidate({id:'42',artworkRevision:'legacy',artworkDetail:'art'},'iOS'),null);
 assert.notEqual(a.identity,mobileArtworkCandidate({id:'42',artworkRevision:'v1',artworkCard:'art'},'Android').identity,'different image coordinate spaces must not share cached regions');
 assert.equal(desktopArtworkCandidate({artworkKey:'abc'},'one').identity,desktopArtworkCandidate({artworkKey:'abc'},'two').identity);
});
test('a single uncacheable image does not prevent later covers from being indexed',async()=>{
 let time=0,id=0;const timers=new Map(),seen=[];
 const indexer=createArtworkIndexer({run:async item=>{seen.push(item.identity);return item.identity==='bad'?'skip':true;},now:()=>time,setTimer:(fn,ms)=>{timers.set(++id,{fn,at:time+ms});return id;},clearTimer:key=>timers.delete(key),interval:10,retryDelay:100});
 const advance=async(ms)=>{time+=ms;for(const [key,timer] of [...timers])if(timer.at<=time){timers.delete(key);timer.fn();}await flush();};
 indexer.update([{source:'a',identity:'bad'},{source:'b',identity:'good'}]);await advance(10);await advance(10);assert.deepEqual(seen,['bad','good']);indexer.dispose();
});
test('clearing pauses reindexing until inspection or a changed catalog',async()=>{
 let time=0,id=0;const timers=new Map(),seen=[];
 const indexer=createArtworkIndexer({run:async item=>{seen.push(item.identity);return true;},now:()=>time,setTimer:(fn,ms)=>{timers.set(++id,{fn,at:time+ms});return id;},clearTimer:key=>timers.delete(key),interval:10});
 const advance=async(ms)=>{time+=ms;for(const [key,timer] of [...timers])if(timer.at<=time){timers.delete(key);timer.fn();}await flush();};
 const items=[{source:'a',identity:'a'}];indexer.update(items);await advance(10);assert.deepEqual(seen,['a']);
 indexer.clear();indexer.update(items);await advance(100);assert.deepEqual(seen,['a']);
 indexer.refresh();await advance(0);assert.deepEqual(seen,['a','a']);indexer.dispose();
});
test('storage recovery retries without discarding a newer catalog',async()=>{
 let time=0,id=0,attempt=0;const timers=new Map(),seen=[];
 const indexer=createArtworkIndexer({run:async item=>{seen.push(item.identity);return ++attempt===1?false:true;},now:()=>time,setTimer:(fn,ms)=>{timers.set(++id,{fn,at:time+ms});return id;},clearTimer:key=>timers.delete(key),interval:10,retryDelay:100});
 const advance=async(ms)=>{time+=ms;for(const [key,timer] of [...timers])if(timer.at<=time){timers.delete(key);timer.fn();}await flush();};
 indexer.update([{source:'a',identity:'a'},{source:'b',identity:'b'}]);await advance(10);indexer.update([{source:'a',identity:'a'},{source:'c',identity:'c'}]);await advance(99);assert.deepEqual(seen,['a']);await advance(1);await advance(10);assert.deepEqual(seen,['a','a','c']);indexer.dispose();
});
