import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeArtworkFraming,artworkFramingKey,updateArtworkAnchor,coverGeometry,dragArtworkAnchor} from '../src/components/artworkFraming.js';
import {stableArtworkFocus,warmArtworkSubjects} from '../src/components/artworkFocus.js';
test('framing defaults to smart, clamps anchors and bounds retained entries',()=>{
 assert.deepEqual(normalizeArtworkFraming(),{mode:'smart',anchors:{}});
 const value=normalizeArtworkFraming({mode:'manual',anchors:Object.fromEntries(Array.from({length:300},(_,i)=>[i,{x:2,y:-1}]))});
 assert.equal(Object.keys(value.anchors).length,256);assert.deepEqual(value.anchors['299'],{x:1,y:0});
 const key=artworkFramingKey({id:'song',artworkRevision:'v1',artwork:'url?epoch=3'});
 assert.equal(key,artworkFramingKey({id:'song',artworkRevision:'v1',artwork:'url?epoch=9'}));
 assert.notEqual(key,artworkFramingKey({id:'song',artworkRevision:'v2'}));
 assert.deepEqual(updateArtworkAnchor(value,key,{x:.2,y:.8}).anchors[key],{x:.2,y:.8});
});
test('manual drag tracks cover overflow, locks orientation axis and never divides by zero',()=>{
 const portrait=coverGeometry(1000,1000,400,800);assert.deepEqual(portrait,{overflowX:400,overflowY:0,portrait:true});
 assert.deepEqual(dragArtworkAnchor({x:.5,y:.3},100,300,portrait),{x:.25,y:.3});
 const landscape=coverGeometry(1000,1000,800,400);assert.deepEqual(dragArtworkAnchor({x:.2,y:.5},300,-100,landscape),{x:.2,y:.75});
 assert.deepEqual(dragArtworkAnchor({x:.5,y:.5},99999,99999,coverGeometry(400,800,400,800)),{x:.5,y:.5});
 assert.deepEqual(dragArtworkAnchor({x:.5,y:.5},99999,0,portrait),{x:0,y:.5});
});
test('expanded smart can refresh after late analysis without breaking stable card crops',async()=>{
 const key='test://full-screen-refresh',image={naturalWidth:1000,naturalHeight:1000,dataset:{},style:{},closest:()=>null},decisions=new Map();
 const options={key,coordinateSpace:'original',viewport:{width:400,height:1000},refreshSubjects:true};
 const first=stableArtworkFocus(image,options,decisions);
 await warmArtworkSubjects(key,async()=>[{x:.8,y:.2,width:.1,height:.2,face:1,confidence:1}]);
 const updated=stableArtworkFocus(image,options,decisions);assert.notDeepEqual(updated,first);assert.ok(updated.x>.8);
});
test('unavailable native response is not cached as successful empty detection',async()=>{
 let calls=0;const read=async()=>{calls++;return calls===1?{}:[];};
 await warmArtworkSubjects('test://unavailable-analysis',read);await warmArtworkSubjects('test://unavailable-analysis',read);await warmArtworkSubjects('test://unavailable-analysis',read);assert.equal(calls,2);
});
test('queued artwork commits merge the latest persisted state across songs',async()=>{
 const {createWorkspaceController}=await import('../src/state.js');let stored={version:1,pages:{}},writes=[];
 const adapter={write:async state=>{writes.push(state);stored=state;},core:async({state,action})=>({...state,pages:{...state.pages,[action.key]:{...state.pages[action.key],...action.patch}}})};
 const controller=createWorkspaceController(adapter);controller.hydrate(stored);
 const save=(key,anchor)=>controller.reduce(state=>({type:'page',key:'appearance',patch:{artworkFraming:updateArtworkAnchor(state.pages.appearance?.artworkFraming,key,anchor)}}));
 await Promise.all([save('song-a',{x:.2,y:.3}),save('song-b',{x:.8,y:.7})]);
 assert.equal(writes.length,2);assert.equal(Object.keys(stored.pages.appearance.artworkFraming.anchors).length,2);
});
