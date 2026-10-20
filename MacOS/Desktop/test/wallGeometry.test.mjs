import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createScene, visibleTiles, wheelStep, releaseDistance, restoredPlayerCamera, wallWorkspaceMetrics } from '../src/wallGeometry.js';

test('all tracks have unique seats and visibility matches exhaustive periodic projection',()=>{
  for(const count of [0,1,7,1040,10000]){
    const scene=createScene(count);assert.equal(scene.tiles.length,count);
    assert.equal(new Set(scene.tiles.map(t=>t.index)).size,count);
    for(const camera of [{x:0,y:0,scale:1},{x:-8400,y:-5600,scale:.6},{x:2800,y:1400,scale:1.4}]){
      const viewport={width:1280,height:820}, actual=visibleTiles(scene,camera,viewport,0);
      assert.equal(new Set(actual.map(t=>t.id)).size,actual.length);
      const expected=[];if(count){
        const left=-camera.x/camera.scale,top=-camera.y/camera.scale,right=left+viewport.width/camera.scale,bottom=top+viewport.height/camera.scale;
        for(let cy=Math.floor(top/scene.world.height);cy<=Math.floor(bottom/scene.world.height);cy++)for(let cx=Math.floor(left/scene.world.width);cx<=Math.floor(right/scene.world.width);cx++)
          for(const tile of scene.tiles){const x=tile.x+cx*scene.world.width,y=tile.y+cy*scene.world.height;if(x<right&&x+tile.width>left&&y<bottom&&y+tile.height>top)expected.push(`${tile.index}:${cx}:${cy}`);}
      }
      assert.deepEqual(actual.map(t=>t.id).sort(),expected.sort());
    }
  }
});
test('60/120Hz wheel motion conserves input and comes to an exact rest',()=>{
  for(const rate of [60,120]){let pending={x:300,y:-200},total={x:0,y:0};for(let i=0;i<rate;i++){const result=wheelStep(pending,1000/rate);pending=result.pending;total.x+=result.step.x;total.y+=result.step.y;}assert.ok(Math.abs(total.x-300)<1e-9);assert.ok(Math.abs(total.y+200)<1e-9);assert.deepEqual(pending,{x:0,y:0});}
});
test('wheel caps stalled frames and coasting has bounded monotonic travel',()=>{
  assert.ok(wheelStep({x:100,y:0},5000).step.x<50);
  assert.ok(releaseDistance(2000,100)<releaseDistance(2000,200));
  assert.equal(releaseDistance(10000,10000),1200);
});
test('collapsing a player preserves a panned camera, but reveals a changed playing card',()=>{
  const saved={x:-940,y:317,sourceID:'7:0:0'},target={id:'7:0:0',x:1200,y:480,width:320,height:400};
  assert.deepEqual(restoredPlayerCamera(saved,target,{width:1000,height:700},260,1),{x:-940,y:317});
  for(const scale of [.8,1,1.2])for(const inset of [0,260]){
    const camera=restoredPlayerCamera(saved,{...target,id:'8:0:0'},{width:1000,height:700},inset,scale);
    assert.equal(camera.x+(target.x+target.width/2)*scale,(1000+inset)/2);
    assert.equal(camera.y+(target.y+target.height/2)*scale,350);
  }
});
test('live wall resize keeps the dock visible and its centre continuous across sidebar breakpoints',()=>{
  for(const sidebar of [false,true]){
    let previous;
    for(let width=480;width<=1600;width++){
      const layout=wallWorkspaceMetrics(width,sidebar),center=(width+layout.leadingInset)/2;
      const left=center-layout.dockWidth/2,right=center+layout.dockWidth/2;
      assert.ok(left>=20&&right<=width-20,`dock clipped at ${width}, sidebar ${sidebar}`);
      if(previous!==undefined)assert.ok(center-previous>=0&&center-previous<=1.001,`centre jumped at ${width}`);
      previous=center;
    }
  }
});
