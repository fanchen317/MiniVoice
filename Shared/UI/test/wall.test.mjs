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

import {mobileWallViewport,wallCardMetrics,lyricWindow,clampZoom} from '../src/wallLayout.js';
test('mobile wall focus and dock budgets fit phone and tablet rotations',()=>{
 for(const [width,height]of [[390,844],[844,390],[1024,1366],[1366,1024],[640,360]]){
  const v=mobileWallViewport(width,height,{top:26,bottom:24});assert(v.side>=120);assert(v.x-v.side/2>=0);assert(v.x+v.side/2<=width);assert(v.y-v.side/2>=26);assert(v.y+v.side/2<=height-24);if(width>height)assert(v.x-v.side/2>v.dockWidth+16);
 }
 assert.equal(clampZoom(9),1.2);assert.equal(clampZoom(.1),.6);
});
test('wall lyric windows keep three or five entries and selected line for every track position',()=>{
 const lines=Array.from({length:30},(_,ms)=>({ms,text:`line ${ms}`}));for(let index=0;index<30;index++){const result=lyricWindow(lines,index,5);assert.equal(result.lines.length,5);assert(result.first<=index&&result.first+5>index);}
 for(const [width,height,compact]of [[240,240,true],[360,360,false],[390,780,false]]){const m=wallCardMetrics(width,height,height>500,compact);assert([3,5].includes(m.count));assert(m.lyricHeight>0);assert(lyricWindow(lines,12,m.count).lines.length>=3);}
 assert.equal(lyricWindow([],0).lines.length,0);
});
test('reflow culling retains every on-screen poster while a focused wall is panned',async()=>{
 const {visibleReflowTiles}=await import('../src/wallGeometry.js');
 for(const count of [4,100,1037]){const scene=createScene(count),focus={...scene.tiles[Math.min(3,count-1)],column:0,row:0},size={width:320,height:320},viewport={width:390,height:844};
  for(const scale of [.6,1,1.2])for(const dx of [-700,0,700]){const camera={x:195-(focus.x+focus.width/2)*scale+dx,y:422-(focus.y+focus.height/2)*scale+300,scale},found=new Set(visibleReflowTiles(scene,camera,viewport,focus,size,0).map(cell=>cell.id));let visible=0;
   for(let row=-3;row<=3;row++)for(let column=-3;column<=3;column++)for(const tile of scene.tiles){const cell={...tile,x:tile.x+column*scene.world.width,y:tile.y+row*scene.world.height},r=reflowFrame(cell,focus,size),x=camera.x+r.x*scale,y=camera.y+r.y*scale;if(x<viewport.width&&x+r.width*scale>0&&y<viewport.height&&y+r.height*scale>0){visible++;assert(found.has(`${tile.index}:${column}:${row}`),`Missing ${count}/${scale}/${dx}/${tile.index}:${column}:${row}`);}}
   assert(visible>0);
  }
 }
});

import {initialWallCamera,DEFAULT_WALL_SCALE} from '../src/wallLayout.js';
test('Android and iOS wall defaults are 100 percent and invalid persisted scales do not become 60 percent',()=>{
 assert.equal(DEFAULT_WALL_SCALE,1);
 for(const camera of [undefined,null,{}, {scale:0},{scale:null},{scale:NaN},{scale:-1}])assert.equal(initialWallCamera(camera).scale,1);
 assert.equal(initialWallCamera({scale:.8}).scale,.8);
 assert.deepEqual(initialWallCamera(),{x:12,y:80,scale:1});
});

test('1037-song reflow visibility matches a full scan at every supported zoom range',async()=>{
 const {visibleReflowTiles}=await import('../src/wallGeometry.js');
 const scene=createScene(1037),focus=scene.tiles[100],size={width:300,height:300},viewport={width:390,height:740};
 const intersects=r=>r.x<viewport.width&&r.y<viewport.height&&r.x+r.width>0&&r.y+r.height>0;
 for(const scale of [.6,1,1.2])for(const delta of [-550,0,550]){
  const camera={x:195-(focus.x+focus.width/2)*scale+delta,y:370-(focus.y+focus.height/2)*scale,scale};
  const projected=cell=>{const r=reflowFrame(cell,focus,size);return {x:camera.x+r.x*scale,y:camera.y+r.y*scale,width:r.width*scale,height:r.height*scale};};
  const expected=[];
  for(let row=-1;row<=1;row++)for(let column=-1;column<=1;column++)for(const tile of scene.tiles){
   const cell={...tile,x:tile.x+column*scene.world.width,y:tile.y+row*scene.world.height,id:`${tile.index}:${column}:${row}`};
   if(intersects(projected(cell)))expected.push(cell.id);
  }
  const actual=visibleReflowTiles(scene,camera,viewport,focus,size,0).filter(cell=>intersects(projected(cell))).map(cell=>cell.id);
  assert.deepEqual(new Set(actual),new Set(expected));
 }
});
