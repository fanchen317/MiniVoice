import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {artworkAnalysisCacheKey,createArtworkAnalysisCache} from '../src/artworkAnalysisCache.js';

test('persistent artwork keys hide source identity and include model version',()=>{
 for(const value of ['artwork://secret-song?v=1','歌曲 🌿','a'.repeat(4096)]){
  const expected=createHash('sha256').update(JSON.stringify(['model-one',value])).digest('hex');
  assert.equal(artworkAnalysisCacheKey(value,'model-one'),expected);
  assert.notEqual(artworkAnalysisCacheKey(value,'model-two'),expected);
 }
 assert.equal(artworkAnalysisCacheKey(''),null);assert.equal(artworkAnalysisCacheKey('a'.repeat(4097)),null);
});
test('unavailable, denied and blocked IndexedDB do not block image analysis',async()=>{
 for(const indexedDB of [null,{open(){throw Error('disabled');}},{open(){return {};}}]){
  const cache=createArtworkAnalysisCache({indexedDB,openTimeoutMs:5});
  assert.equal(await cache.available(),false);
  assert.equal(await cache.get('artwork-v1'),null);
  assert.equal(await cache.put('artwork-v1',[]),false);
  assert.equal(await cache.clear(),false);
 }
});
test('invalid detection output is never stored',async()=>{
 let called=false;const cache=createArtworkAnalysisCache({indexedDB:{open(){called=true;throw Error('unused');}}});
 for(const bad of [null,[{x:0,y:0,width:-1,height:1,confidence:1}],[{x:.9,y:0,width:.3,height:1,confidence:1}],Array.from({length:49},()=>({}))])assert.equal(await cache.put('id',bad),false);
 const tooLarge=Array.from({length:48},()=>({x:.123456789012345,y:.123456789012345,width:.123456789012345,height:.123456789012345,confidence:.123456789012345}));
 assert.equal(await cache.put('id',tooLarge),false);
 assert.equal(called,false);
});
test('storage failures cool down before retrying instead of delaying each click',async()=>{
 let time=1000,attempts=0;
 const cache=createArtworkAnalysisCache({indexedDB:{open(){attempts++;throw Error('blocked');}},now:()=>time});
 assert.equal(await cache.get('first'),null);assert.equal(await cache.get('second'),null);assert.equal(attempts,1);
 time+=30001;assert.equal(await cache.get('third'),null);assert.equal(attempts,2);
});
