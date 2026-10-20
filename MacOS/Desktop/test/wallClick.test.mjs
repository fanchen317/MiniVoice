import {test} from 'node:test';
import assert from 'node:assert/strict';
import {WallClickSequence} from '../src/wallClick.js';
const tap=(sequence,id,time,extra={})=>sequence.click({id,x:240,y:180,time,...extra});

test('an already focused preview accepts a fresh double-click long after its original focus',()=>{
  const clicks=new WallClickSequence();
  tap(clicks,'preview',0);
  assert.equal(tap(clicks,'preview',10000).type,'single');
  assert.deepEqual(tap(clicks,'preview',10250),{type:'play',id:'preview'});
});
test('reflow can move another card, player text, or a control under the second click',()=>{
  for(const extra of [{id:'neighbor'},{id:'original',control:true},{id:undefined}]){
    const clicks=new WallClickSequence();tap(clicks,'original',100);
    assert.deepEqual(tap(clicks,extra.id,350,extra),{type:'play',id:'original'});
    assert.equal(tap(clicks,'original',400).type,'single','a double-click dispatches playback only once');
  }
});
test('ordinary controls keep their own clicks and do not seed poster playback',()=>{
  const clicks=new WallClickSequence();
  tap(clicks,'song',0,{control:true});
  assert.equal(tap(clicks,'song',200,{control:true}).type,'single');
  assert.equal(tap(clicks,'song',300).type,'single');
});
test('moving, waiting, panning, keyboard actions and group navigation break continuation',()=>{
  for(const extra of [{x:247},{y:187},{keyboard:true},{time:601}]){
    const clicks=new WallClickSequence();tap(clicks,'first',100);
    assert.equal(tap(clicks,'second',300,extra).type,'single');
  }
  const clicks=new WallClickSequence();tap(clicks,'first',100);clicks.reset();
  assert.equal(tap(clicks,'second',300).type,'single');
  clicks.reset();tap(clicks,'group',100,{group:true});
  assert.equal(tap(clicks,'song',300).type,'single');
});
test('the system double-click interval is respected without depending on browser target identity',()=>{
  for(const interval of [250,500,1100]){
    const clicks=new WallClickSequence();clicks.click({id:'first',x:0,y:0,time:100},interval);
    assert.deepEqual(clicks.click({id:'moved',x:3,y:4,time:100+interval},interval),{type:'play',id:'first'});
    clicks.click({id:'first',x:0,y:0,time:2000},interval);
    assert.equal(clicks.click({id:'moved',x:0,y:0,time:2001+interval},interval).type,'single');
  }
});
