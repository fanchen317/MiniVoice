import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createScene,visibleTiles,nearestInstance,reflowFrame} from '../src/wallGeometry.js';
test('phone uses original weighted tessellation and periodic instances',()=>{
 const scene=createScene(162);assert.equal(scene.tiles.length,162);
 assert(new Set(scene.tiles.map(t=>Math.round(t.width))).size>3);
 for(const scale of [.6,1,1.6]){const camera={x:-12008,y:9831,scale},viewport={width:412,height:840};const visible=visibleTiles(scene,camera,viewport,120);assert(visible.length>0&&visible.length<200);assert.equal(new Set(visible.map(t=>t.id)).size,visible.length);const cell=nearestInstance(scene,4,camera,viewport);assert.equal(cell.index,4);}
});
test('focused cover reserves a square and pushes neighboring shared edges',()=>{
 const focus={x:0,y:0,width:175,height:175};const expanded=reflowFrame(focus,focus,{width:330,height:330});assert.equal(expanded.width,330);assert.equal(expanded.height,330);
 const neighbor=reflowFrame({x:180,y:0,width:175,height:175},focus,{width:330,height:330});assert.equal(neighbor.x-expanded.x-expanded.width,5);assert.equal(neighbor.height,330);
});
