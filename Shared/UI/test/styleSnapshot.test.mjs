import test from 'node:test';
import assert from 'node:assert/strict';
import {captureStyleSnapshot} from '../src/styleTransition.js';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
test('local snapshot crosses the bridge as a small lease and releases exactly once after its raster is copied',async()=>{
 const requests=[];const snapshot=captureStyleSnapshot(async request=>{requests.push(request);return {src:'https://minivoice.local/style-snapshot/12',token:'12'};});
 assert.equal(await snapshot.pending,'https://minivoice.local/style-snapshot/12');assert.deepEqual(requests,[undefined]);
 snapshot.release();snapshot.release();await turn();assert.deepEqual(requests,[undefined,{phase:'release',token:'12'}]);
});
test('a timed-out or interrupted snapshot releases its late native result without publishing it',async()=>{
 let resolve;const requests=[];const snapshot=captureStyleSnapshot(request=>{if(request){requests.push(request);return true;}return new Promise(done=>{resolve=done;});});
 await turn();snapshot.release();resolve({src:'https://minivoice.local/style-snapshot/9',token:'9'});
 assert.equal(await snapshot.pending,null);await turn();assert.deepEqual(requests,[{phase:'release',token:'9'}]);
});
test('legacy fixture and Mac data URLs remain unchanged and do not send a release RPC',async()=>{
 const requests=[],source='data:image/jpeg;base64,c3ludGhldGlj';const snapshot=captureStyleSnapshot(async request=>{requests.push(request);return source;});
 assert.equal(await snapshot.pending,source);snapshot.release();assert.deepEqual(requests,[undefined]);
});
test('snapshot or release failure cannot block the style update or leak an unhandled rejection',async()=>{
 const failed=captureStyleSnapshot(()=>Promise.reject(Error('unavailable')));assert.equal(await failed.pending,null);failed.release();
 const source=captureStyleSnapshot(request=>request?Promise.reject(Error('host closed')):Promise.resolve({src:'local',token:'1'}));
 assert.equal(await source.pending,'local');assert.doesNotThrow(()=>source.release());await turn();
});
