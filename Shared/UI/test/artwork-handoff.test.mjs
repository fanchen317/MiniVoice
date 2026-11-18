import test from 'node:test';
import assert from 'node:assert/strict';
import {waitForArtworkPreparation} from '../src/artworkHandoff.js';

function fakeTimer(){let callback,cleared=0;return {setTimer(fn){callback=fn;return 1;},clearTimer(){cleared++;},fire(){callback();},get cleared(){return cleared;}};}
test('completed or failed preparation does not block a handoff',async()=>{
 const timer=fakeTimer(),result=waitForArtworkPreparation([Promise.resolve(),Promise.reject(Error('offline'))],timer);
 assert.equal(await result,true);assert.equal(timer.cleared,1);
});
test('a stuck model or image request has a bounded wait and ignores late completion',async()=>{
 const timer=fakeTimer();let finish;const work=new Promise(resolve=>{finish=resolve;});
 const result=waitForArtworkPreparation([work],timer);timer.fire();assert.equal(await result,false);finish();await Promise.resolve();assert.equal(timer.cleared,1);
});
