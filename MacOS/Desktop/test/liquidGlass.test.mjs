import {test} from 'node:test';
import assert from 'node:assert/strict';
import {glassDisplacement} from '../src/liquidGlass.js';

test('glass lens leaves the centre clear and bends opposite rims symmetrically',()=>{
  assert.deepEqual(glassDisplacement(460,64,230,32),[128,128]);
  const left=glassDisplacement(460,64,2,32),right=glassDisplacement(460,64,458,32);
  assert.ok(left[0]>128&&right[0]<128);
  assert.ok(Math.abs(left[0]+right[0]-256)<1e-8);
  assert.equal(left[1],128);assert.equal(right[1],128);
});
test('circular and stretched capsule lenses keep bounded colour channels',()=>{
  for(const [w,h] of [[38,38],[176,38],[460,64]])for(let y=0;y<h;y+=2)for(let x=0;x<w;x+=2){
    const channels=glassDisplacement(w,h,x,y);
    assert.ok(channels.every(value=>Number.isFinite(value)&&value>=0&&value<=255));
  }
});

test('tall sidebar lens keeps its flat interior and 15pt rounded corners',()=>{
  assert.deepEqual(glassDisplacement(230,680,115,340,15),[128,128]);
  assert.ok(glassDisplacement(230,680,2,340,15)[0]>128);
  assert.ok(glassDisplacement(230,680,115,2,15)[1]>128);
  assert.deepEqual(glassDisplacement(230,680,30,340,15),[128,128]);
});
