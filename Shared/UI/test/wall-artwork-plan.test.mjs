import test from 'node:test';
import assert from 'node:assert/strict';
import {wallArtworkPlan,anticipatedWallCamera} from '../src/wallArtworkPlan.js';
import {createScene,visibleReflowTiles} from '../src/wallGeometry.js';
test('wall artwork speculation favours visible sources, deduplicates repeats and stays bounded',()=>{
 const items=Array.from({length:1037},(_,id)=>({artwork:`card-${id}`,artworkWall:`wall-${id}`})),scene=createScene(items.length),viewport={width:800,height:1200},camera={x:0,y:0,scale:.5};
 const cells=visibleReflowTiles(scene,camera,viewport,null,{width:320,height:320},600),plan=wallArtworkPlan(cells,items,camera,viewport);
 assert.ok(plan.length>0&&plan.length<=48);assert.equal(new Set(plan).size,plan.length);assert.ok(plan.every(source=>source.startsWith('wall-')));
 const custom=wallArtworkPlan([{index:0,x:-900,y:0,width:80,height:80},{index:1,x:50,y:50,width:80,height:80},{index:1,x:60,y:60,width:80,height:80}],items,{x:0,y:0,scale:1},viewport);
 assert.deepEqual(custom,['wall-1','wall-0']);
});
test('prediction follows the latest pan direction and resets for zoom or first render',()=>{
 const camera={x:-200,y:100,scale:1},next=anticipatedWallCamera(camera,{x:0,y:0,scale:1});
 assert.ok(next.x<camera.x&&next.y>camera.y);assert.ok(Math.hypot(next.x-camera.x,next.y-camera.y)<=420.001);
 const reverse=anticipatedWallCamera({x:-100,y:50,scale:1},camera);assert.ok(reverse.x>-100&&reverse.y<50);
 assert.equal(anticipatedWallCamera(camera,null),camera);assert.equal(anticipatedWallCamera(camera,{x:0,y:0,scale:.5}),camera);
});
