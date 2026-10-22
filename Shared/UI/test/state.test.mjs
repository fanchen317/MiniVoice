import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createWorkspaceController,stableSongs} from '../src/state.js';
import {createAndroidTransport,createSnapshotReader} from '../src/platform.js';
test('rapid changes preserve parent anchor, navigation and appearance',async()=>{
 let persisted;const controller=createWorkspaceController({core:async({state,action})=>{await new Promise(resolve=>setTimeout(resolve,3));return {...state,pages:{...state.pages,[action.key]:{...state.pages[action.key],...action.patch}}};},write:async state=>{persisted=state;}});
 controller.hydrate({version:1,pages:{}});
 await Promise.all([controller.reduce({key:'artist',patch:{identity:'a',index:24,offset:-9}}),controller.reduce({key:'appearance',patch:{theme:'dark'}}),controller.reduce({key:'artist',patch:{query:'林'}})]);
 assert.deepEqual(persisted.pages.artist,{identity:'a',index:24,offset:-9,query:'林'});assert.equal(persisted.pages.appearance.theme,'dark');
});
test('clock polling preserves the list identity and does not reset the scroll effect',()=>{
 const before=[{id:'1',title:'A'}];assert.equal(stableSongs(before,structuredClone(before)),before);assert.notEqual(stableSongs(before,[{id:'1',title:'B'}]),before);
});
test('bridge correlates concurrent replies, rejects errors and recovers from timeout',async()=>{
 const messages=[];const send=createAndroidTransport({request:(id,raw)=>messages.push([id,JSON.parse(raw)])},20);
 const a=send({kind:'snapshot'}),b=send({kind:'core'});globalThis.MiniVoiceTransport.receive(messages[1][0],{ok:true,value:2});globalThis.MiniVoiceTransport.receive(messages[0][0],{ok:true,value:1});assert.deepEqual(await Promise.all([a,b]),[1,2]);
 const failure=send({kind:'invalid'});globalThis.MiniVoiceTransport.receive(messages[2][0],{ok:false,error:'unsupported'});await assert.rejects(failure,/unsupported/);
 await assert.rejects(send({kind:'timeout'}),/超时/);assert.equal(messages[0][1].version,1);
});

test('clock snapshots reuse catalog references and carry the last revision',async()=>{const revisions=[],songs=[{id:'9223372036854775806'}];let first=true;const read=createSnapshotReader(async revision=>{revisions.push(revision);const value={songs:first?songs:null,catalogRevision:'a',position:first?0:900};first=false;return value;});const a=await read(),b=await read();assert.equal(a.songs,b.songs);assert.deepEqual(revisions,['','a']);assert.equal(b.position,900);});
