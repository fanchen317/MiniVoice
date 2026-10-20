import {test} from 'node:test';
import assert from 'node:assert/strict';
import {wallZoomStops,nextWallZoomStop} from '../src/wallZoom.js';

test('zoom buttons visit every requested stop and clamp at endpoints',()=>{
  assert.deepEqual(wallZoomStops,[60,70,80,90,100,110,120]);
  for(let i=0;i<wallZoomStops.length;i++){
    assert.equal(nextWallZoomStop(wallZoomStops[i]/100,1),wallZoomStops[Math.min(i+1,6)]/100);
    assert.equal(nextWallZoomStop(wallZoomStops[i]/100,-1),wallZoomStops[Math.max(i-1,0)]/100);
  }
});

test('zoom buttons choose neighboring stops after a continuous pinch gesture',()=>{
  assert.equal(nextWallZoomStop(.834,1),.9);
  assert.equal(nextWallZoomStop(.834,-1),.8);
  assert.equal(nextWallZoomStop(1.0000001,-1),.9);
});
