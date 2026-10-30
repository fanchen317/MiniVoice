import test from 'node:test';
import assert from 'node:assert/strict';
import {WALL_PAN_GUARD,WALL_PAN_REBASE,rasterCamera,projectWallFrame} from '../src/wallProjection.js';
test('bounded iOS plane has continuous screen coordinates across repeated raster rebases',()=>{
 let base=null;const frame={x:203,y:97,width:170,height:220};
 for(let index=-100;index<100;index++){
  const c={x:index*17,y:-index*11,scale:.8};base=rasterCamera(base,c);
  const local=projectWallFrame(frame,base,WALL_PAN_GUARD);
  assert(Math.abs(local.x-WALL_PAN_GUARD+c.x-base.x-(c.x+frame.x*c.scale))<1e-8);
  assert(Math.abs(local.y-WALL_PAN_GUARD+c.y-base.y-(c.y+frame.y*c.scale))<1e-8);
  assert(Math.abs(c.x-base.x)<=WALL_PAN_REBASE);
  assert(WALL_PAN_GUARD>Math.abs(c.x-base.x));
 }
});
test('zoom rebases immediately and Android projection uses unchanged viewport coordinates',()=>{
 const c={x:12,y:80,scale:1.2},base=rasterCamera({x:0,y:0,scale:1},c);
 assert.deepEqual(base,c);assert.deepEqual(projectWallFrame({x:5,y:10,width:20,height:30},c),{x:18,y:92,width:24,height:36});
});

import {createScene,visibleTiles,playingInstance,nearestInstance} from '../src/wallGeometry.js';
test('small libraries give only one repeated card playback emphasis and retain the focused instance',()=>{
 for(const count of [2,3]){
  const scene=createScene(count),camera={x:12,y:80,scale:1},viewport={width:900,height:900};
  const tiles=visibleTiles(scene,camera,viewport),owner=playingInstance(scene,0,camera,viewport,null);
  assert(tiles.filter(cell=>cell.index===0).length>1);
  assert.equal(tiles.filter(cell=>cell.id===owner.id).length,1);
  const other=tiles.find(cell=>cell.index===0&&cell.id!==owner.id);
  assert.equal(playingInstance(scene,0,camera,viewport,other).id,other.id);
  assert.equal(playingInstance(scene,1,camera,viewport,other).id,nearestInstance(scene,1,camera,viewport).id);
  assert.equal(playingInstance(scene,-1,camera,viewport,other),null);
 }
});

import {nearestRenderedInstance} from '../src/wallGeometry.js';
test('locating repeated songs uses rendered centres and survives long camera travel',()=>{
 for(const count of [2,3,1037])for(const scale of [.6,1,1.2]){
  const scene=createScene(count),camera={x:-12345,y:9876,scale},viewport={width:412,height:840};
  const seed=nearestInstance(scene,0,camera,viewport);
  // Reflow can move the seed away while leaving the adjacent repeat close.
  const neighbour={...seed,column:seed.column+1,id:`0:${seed.column+1}:${seed.row}`,x:seed.x+scene.world.width};
  const frame=cell=>cell.id===neighbour.id?{...cell,x:(viewport.width/2-camera.x)/scale-cell.width/2,y:(viewport.height/2-camera.y)/scale-cell.height/2}:{...cell,x:cell.x+scene.world.width*4};
  assert.equal(nearestRenderedInstance(scene,0,camera,viewport,frame).id,neighbour.id);
  assert.equal(nearestRenderedInstance(scene,-1,camera,viewport,frame),null);
 }
});
