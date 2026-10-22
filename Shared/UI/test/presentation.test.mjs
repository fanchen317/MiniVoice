import {test} from 'node:test';
import assert from 'node:assert/strict';
import {presentationFor,layoutFor} from '../src/presentation.js';
import {playlistPageActions} from '../src/state.js';
test('Mac remains desktop in a narrow window; Android/iOS/Harmony remain touch layouts when wide',()=>{
 assert.equal(presentationFor({platform:'macos',width:320}).reference,'mac');for(const platform of ['android','ios','harmony'])assert.deepEqual(presentationFor({platform,width:1400}),{family:'mobile',reference:'android',navigation:'drawer',contextMenu:'sheet',primaryInput:'touch'});for(const platform of ['windows','linux'])assert.equal(presentationFor({platform}).reference,'mac');
});
test('renaming a phone playlist moves its scroll/search/expansion state and deletion leaves other pages alone',()=>{
 const page={identity:'9223372036854775806',index:15,offset:-12,query:'周',player:true},state={section:'歌单:旧歌单',group:'',pages:{'歌单:旧歌单\n':page,'歌手\n':{query:'林'}}};
 const changes=playlistPageActions(state,'旧歌单','新歌单');assert.deepEqual(changes[0],{type:'page',key:'歌单:新歌单\n',patch:page});assert.deepEqual(changes.at(-1),{type:'navigate',section:'歌单:新歌单',group:''});assert.equal(changes.some(action=>action.key==='歌手\n'),false);assert.equal(playlistPageActions(state,'旧歌单',null).at(-1).section,'音乐库');assert.deepEqual(playlistPageActions(state,'旧歌单','旧歌单'),[]);
});
test('playlist deletion preserves an unrelated selected page',()=>{const changes=playlistPageActions({section:'歌手',pages:{'歌单:A\n':{query:'x'},'歌手\n':{index:6}}},'A',null);assert.equal(changes.some(action=>action.type==='navigate'),false);assert.deepEqual(changes,[{type:'page',key:'歌单:A\n',patch:null}]);});

test('tablet and phone share touch behavior, desktop stays keyboard/mouse at every size',()=>{
 for(const platform of ['android','ios','harmony']){
  const mobile=presentationFor({platform});
  for(const viewport of [{width:390,height:844},{width:844,height:390},{width:1024,height:1366},{width:1366,height:1024}]){
   const result=layoutFor(mobile,viewport);assert.equal(result.family,'mobile');assert.equal(result.input,'touch');assert.equal(result.minimumTarget,44);assert.equal(result.device,Math.min(viewport.width,viewport.height)>=600?'tablet':'phone');
  }
  assert.equal(layoutFor(mobile,{width:1024,height:1366}).dialog,'center');
  assert.equal(layoutFor(mobile,{width:390,height:844}).dialog,'bottom');
 }
 const compact=layoutFor(presentationFor({platform:'macos'}),{width:390,height:844});assert.equal(compact.device,'computer');assert.equal(compact.input,'keyboard-mouse');assert.equal(compact.dialog,'center');
 assert.equal(presentationFor({platform:'android',deviceClass:'desktop'}).family,'desktop');
 assert.equal(presentationFor({platform:'macos',deviceClass:'tablet'}).family,'mobile');
});
