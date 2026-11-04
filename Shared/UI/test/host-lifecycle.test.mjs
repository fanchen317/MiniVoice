import test from 'node:test';
import assert from 'node:assert/strict';
import {createAndroidTransport} from '../src/platform.js';
import {startSnapshotPolling} from '../src/hostPolling.js';
function environment(){let time=0,serial=0;const jobs=new Map(),document=new EventTarget(),lifecycle=new EventTarget();document.hidden=false;return {document,lifecycle,now:()=>time,setTimer:(fn,delay)=>{jobs.set(++serial,{fn,at:time+delay});return serial;},clearTimer:id=>jobs.delete(id),advance(delta){const end=time+delta;for(;;){const first=[...jobs].sort((a,b)=>a[1].at-b[1].at)[0];if(!first||first[1].at>end)break;time=first[1].at;jobs.delete(first[0]);first[1].fn();}time=end;},suspend(delta){time+=delta;const due=[...jobs].filter(([,job])=>job.at<=time);for(const [id,job]of due){jobs.delete(id);job.fn();}},visibility(hidden){document.hidden=hidden;document.dispatchEvent(new Event('visibilitychange'));}};}
const flush=async()=>{await Promise.resolve();await Promise.resolve();};
test('transport excludes background suspension and still times out an unresponsive foreground host',async()=>{
 const env=environment(),requests=[],send=createAndroidTransport({request:(id,raw)=>requests.push({id,raw})},1000,env);
 let settled=false;const pending=send({kind:'snapshot'}).then(value=>{settled=true;return value;});env.advance(400);env.visibility(true);env.advance(60000);env.visibility(false);env.advance(400);await flush();assert.equal(settled,false);
 globalThis.MiniVoiceTransport.receive(requests[0].id,{ok:true,value:42});assert.equal(await pending,42);
 const failure=send({kind:'toggle'}).catch(error=>error);env.advance(1000);assert.equal((await failure).code,'HOST_TIMEOUT');assert.equal(requests.length,2);send.dispose();
});
test('a frozen JS event loop does not reject queued native replies on wake; late replies do not replay writes',async()=>{
 const env=environment(),ids=[],send=createAndroidTransport({request:id=>ids.push(id)},1000,env);let settled=false;
 const pending=send({kind:'play'}).then(()=>settled=true);env.suspend(120000);await flush();assert.equal(settled,false);globalThis.MiniVoiceTransport.receive(ids[0],{ok:true,value:true});await pending;assert.equal(ids.length,1);send.dispose();
});
test('polling stops while hidden, resumes once, retains one in-flight read and reports persistent failures',async()=>{
 const env=environment();let calls=0,resolve,errors=0,recovered=0,fail=false;
 const stop=startSnapshotPolling({...env,read:()=>{calls++;return fail?Promise.reject(Error('offline')):new Promise(done=>resolve=done);},onValue:()=>{},onError:()=>errors++,onRecovered:()=>recovered++});
 env.visibility(true);env.advance(60000);assert.equal(calls,1);resolve({});await flush();env.visibility(false);assert.equal(calls,2);env.visibility(false);assert.equal(calls,2);resolve({});await flush();
 fail=true;env.advance(450);await flush();env.advance(1000);await flush();assert.equal(errors,0);env.advance(2000);await flush();assert.equal(errors,1);env.advance(4000);await flush();assert.equal(errors,1);
 fail=false;env.advance(8000);resolve({});await flush();assert.equal(recovered,1);stop();env.advance(20000);assert.equal(errors,1);
});
