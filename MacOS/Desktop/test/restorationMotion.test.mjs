import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fragmentCells,fragmentProgress,springProgress,playerDetailMetrics} from '../src/motion.js';
import {createScene,reflowFrame,focusProgress,reflowProgress,nearestInstance} from '../src/wallGeometry.js';

test('style fragments cover the entire window and the sweep finishes at the native deadline',()=>{
  for(const [width,height] of [[304,600],[944,628],[1280,820],[4000,2000]]){
    const cells=fragmentCells(width,height),area=cells.reduce((n,r)=>n+r.width*r.height,0);
    assert.ok(Math.abs(area-width*height)<.001);assert.ok(cells.length<=224);
    for(const cell of cells){const center={x:cell.x+cell.width/2,y:cell.y+cell.height/2};assert.equal(fragmentProgress(0,center,{x:36,y:60},{width,height}),0);assert.equal(fragmentProgress(680,center,{x:36,y:60},{width,height}),1);}
  }
});
test('expanded wall cells keep shared edges and exact five-point gutters',()=>{
  const focus={x:100,y:100,width:195,height:195},size={width:480,height:480};
  const left={x:0,y:100,width:95,height:195},right={x:300,y:100,width:95,height:195},above={x:100,y:0,width:195,height:95};
  const f=reflowFrame(focus,focus,size),l=reflowFrame(left,focus,size),r=reflowFrame(right,focus,size),a=reflowFrame(above,focus,size);
  assert.equal(f.width,480);assert.equal(f.height,480);assert.equal(f.x-l.x-l.width,5);assert.equal(r.x-f.x-f.width,5);assert.equal(f.y-a.y-a.height,5);
  const tiles=createScene(1040).tiles;for(const tile of tiles){const frame=reflowFrame(tile,focus,size);assert.ok(frame.width>0&&frame.height>0);}
});
test('focus and reflow are bounded monotonic curves independent of display refresh',()=>{
  for(const fn of [focusProgress,p=>reflowProgress(p*520)]){let last=0;assert.equal(fn(0),0);for(let i=1;i<=240;i++){const next=fn(i/240);assert.ok(next>=last&&next<=1);last=next;}assert.equal(last,1);}
  for(const rate of [60,120]){let value=0;for(let i=0;i<=rate;i++)value=springProgress(i/rate*1000);assert.ok(Math.abs(value-1)<.001);}
});
test('locating a periodic poster chooses its nearest world copy after distant panning',()=>{
  const scene=createScene(1040),viewport={width:1280,height:820};
  for(const scale of [.6,1,1.4])for(const offset of [-1e7,0,1e7]){
    const camera={x:offset,y:-offset,scale},tile=nearestInstance(scene,738,camera,viewport);
    const x=(tile.x+tile.width/2)*scale+camera.x,y=(tile.y+tile.height/2)*scale+camera.y;
    assert.ok(Math.abs(x-viewport.width/2)<=scene.world.width*scale/2+.001);assert.ok(Math.abs(y-viewport.height/2)<=scene.world.height*scale/2+.001);
  }
});

test('simple hero respects the lyric budget and native title-size thresholds',()=>{
  const small=playerDetailMetrics({width:434,height:729,controls:172});assert.equal(small.titleSize,20);assert.ok(small.artworkSize<=434*.34);
  const medium=playerDetailMetrics({width:800,height:820,controls:106});assert.equal(medium.titleSize,23);
  const large=playerDetailMetrics({width:1000,height:1200,controls:106});assert.equal(large.artworkSize,260);assert.equal(large.titleSize,30);
  const constrained=playerDetailMetrics({width:1000,height:605,controls:172});assert.equal(constrained.artworkSize,(605-46)*.23);assert.equal(constrained.titleSize,20);
});

test('wall dock keeps its native endpoint sizes and reveals details continuously',async()=>{
  const {wallDockMetrics}=await import('../src/motion.js');
  const small=wallDockMetrics(240),large=wallDockMetrics(460);
  assert.deepEqual(small,{detail:0,spacing:8,padding:12,playSide:40,playFont:24});
  assert.deepEqual(large,{detail:1,spacing:12,padding:16,playSide:46,playFont:26});
  let last=0;
  for(let width=240;width<=460;width+=.5){const m=wallDockMetrics(width);assert.ok(m.detail>=last&&m.detail<=1);assert.ok(m.detail-last<.01);assert.ok(width-2*m.padding-m.playSide-2*m.spacing-32-31*m.detail>80);last=m.detail;}
});

test('browse grids keep native compact rows and fit every card inside the panel',async()=>{
  const {browseGridMetrics}=await import('../src/motion.js');
  assert.equal(browseGridMetrics(343,false).compact,true);
  assert.equal(browseGridMetrics(344,false).columns,2);
  for(let panelWidth=280;panelWidth<=2000;panelWidth++)for(const artist of [false,true]){
    const m=browseGridMetrics(panelWidth,artist);
    assert.ok(m.width*m.columns+(m.columns-1)*16<=panelWidth-56+.001);
    assert.ok(m.artwork<=m.width-16);
    assert.ok(m.height>=m.artwork+16);
    if(m.compact){assert.equal(m.artwork,54);assert.equal(m.height,70);assert.equal(m.stride,74);}
  }
});

test('poster artwork fills intermediate bounds without stretching its intrinsic aspect ratio',async()=>{
  const {posterArtworkMotion}=await import('../src/motion.js');
  for(const ratio of [.6,1,1.8])for(const [from,to] of [[{width:120,height:400},{width:480,height:480}],[{width:480,height:480},{width:1280,height:820}],[{width:1280,height:820},{width:200,height:420}]]){
    const motion=posterArtworkMotion(from,to,ratio,p=>p);
    for(const frame of motion.frames){
      const [x,y]=frame.transform.match(/scale\(([^,]+),([^\)]+)\)/).slice(1).map(Number),p=frame.offset;
      const w=from.width+(to.width-from.width)*p,h=from.height+(to.height-from.height)*p,inkWidth=motion.width*x*w/to.width,inkHeight=motion.height*y*h/to.height;
      assert.ok(Math.abs(inkWidth/inkHeight-ratio)<1e-9);
      assert.ok(inkWidth>=w-1e-9&&inkHeight>=h-1e-9);
    }
  }
});
