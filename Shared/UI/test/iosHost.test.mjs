import test from 'node:test';
import assert from 'node:assert/strict';
import {platformAdapter,createAndroidTransport,createSnapshotReader} from '../src/platform.js';

test('iOS host uses the same mobile DTO commands and Android-reference presentation',async()=>{
 const requests=[];
 globalThis.MiniVoiceHost={platform:'ios',request(id,raw){
  const request=JSON.parse(raw);requests.push(request);
  queueMicrotask(()=>globalThis.MiniVoiceTransport.receive(id,{ok:true,value:request.kind==='snapshot'?{songs:[],catalogRevision:'1'}:true}));
 }};
 try{
  const adapter=platformAdapter();
  assert.equal(adapter.name,'iOS');
  assert.equal(adapter.portraitDock,'center');
  assert.equal(adapter.presentation.family,'mobile');
  assert.equal(adapter.presentation.reference,'android');
  await adapter.play('song-a',['song-a']);
  await adapter.seek(12000);
  await adapter.action('mode',{value:4});
  await adapter.snapshot();await adapter.snapshot();
  assert.deepEqual(requests[0],{kind:'play',id:'song-a',ids:['song-a'],version:1});
  assert.equal(requests[1].position,12000);
  assert.equal(requests[2].payload.value,4);
  assert.equal(requests.at(-1).catalogRevision,'1');
  assert.ok(requests.every(value=>value.version===1));
 }finally{delete globalThis.MiniVoiceHost;delete globalThis.MiniVoiceTransport;}
});

test('transport rejects host errors and discards late replies',async()=>{
 let id;
 const send=createAndroidTransport({request(value){id=value;}},1000);
 const pending=send({kind:'play'});
 globalThis.MiniVoiceTransport.receive(id,{ok:false,error:'歌曲未授权'});
 await assert.rejects(pending,/歌曲未授权/);
 assert.doesNotThrow(()=>globalThis.MiniVoiceTransport.receive(id,{ok:true,value:'late'}));
 delete globalThis.MiniVoiceTransport;
});

test('unchanged catalog keeps array identity through native playback clock polling',async()=>{
 const songs=[{id:'one'}];let count=0;
 const read=createSnapshotReader(async()=>({songs:count++===0?songs:null,catalogRevision:'same',position:count*250}));
 assert.equal((await read()).songs,(await read()).songs);
});
