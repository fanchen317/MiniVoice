// Deterministic weighted partition of MiniVoice's own poster layout. Spatial
// buckets bound visibility queries; camera transforms never pass through React.
export function createScene(count) {
  if (!count) return { tiles: [], world: { width: 1, height: 1 }, buckets: new Map() };
  const pattern = [2,1,1,3,1,2,1,1,2,4,1,2], sums = [0];
  for (let i = 0; i < count; i++) sums.push(sums[i] + pattern[i % pattern.length]);
  const area = sums[count] * 180 * 180;
  const world = { width: Math.sqrt(area * 1.6), height: Math.sqrt(area / 1.6) }, tiles = [], buckets = new Map();
  function divide(first, end, x, y, width, height) {
    if (end - first === 1) { tiles.push({ index: first, x, y, width: width - 5, height: height - 5 }); return; }
    const middle = first + Math.floor((end - first) / 2), fraction = (sums[middle] - sums[first]) / (sums[end] - sums[first]);
    if (width >= height) { divide(first, middle, x, y, width * fraction, height); divide(middle, end, x + width * fraction, y, width * (1-fraction), height); }
    else { divide(first, middle, x, y, width, height * fraction); divide(middle, end, x, y + height * fraction, width, height * (1-fraction)); }
  }
  divide(0, count, 0, 0, world.width, world.height);
  for (const tile of tiles) for (let y = Math.floor(tile.y / 640); y <= Math.floor((tile.y + tile.height) / 640); y++)
    for (let x = Math.floor(tile.x / 640); x <= Math.floor((tile.x + tile.width) / 640); x++) {
      const key = `${x}:${y}`; if (!buckets.has(key)) buckets.set(key, []); buckets.get(key).push(tile);
    }
  return { tiles, world, buckets };
}
export function visibleTiles(scene, camera, viewport, overscan = 400) {
  if (!scene.tiles.length || !viewport.width || !viewport.height) return [];
  const { scale, x, y } = camera, { world, buckets } = scene;
  const left = (-x - overscan) / scale, right = (viewport.width - x + overscan) / scale;
  const top = (-y - overscan) / scale, bottom = (viewport.height - y + overscan) / scale;
  const output = [];
  for (let cy = Math.floor(top/world.height); cy <= Math.floor(bottom/world.height); cy++)
    for (let cx = Math.floor(left/world.width); cx <= Math.floor(right/world.width); cx++) {
      const l = Math.max(0, left-cx*world.width), r = Math.min(world.width, right-cx*world.width);
      const t = Math.max(0, top-cy*world.height), b = Math.min(world.height, bottom-cy*world.height);
      if (r < l || b < t) continue;
      const nearby = new Set();
      for (let by = Math.floor(t/640); by <= Math.floor(b/640); by++) for (let bx = Math.floor(l/640); bx <= Math.floor(r/640); bx++)
        for (const tile of buckets.get(`${bx}:${by}`) || []) nearby.add(tile);
      for (const tile of nearby) if (tile.x < r && tile.x+tile.width > l && tile.y < b && tile.y+tile.height > t)
        output.push({ ...tile, column:cx,row:cy,id: `${tile.index}:${cx}:${cy}`, x: tile.x+cx*world.width, y: tile.y+cy*world.height });
    }
  return output;
}
export function wheelStep(pending, elapsed) {
  const factor = 1 - Math.exp(-Math.min(50, Math.max(0, elapsed)) / 80);
  if (Math.hypot(pending.x, pending.y) * (1-factor) < .5) return { step: { ...pending }, pending: { x: 0, y: 0 } };
  return { step: { x: pending.x*factor, y: pending.y*factor }, pending: { x: pending.x*(1-factor), y: pending.y*(1-factor) } };
}
export function releaseDistance(speed, elapsed) {
  const target = Math.min(4000, Math.max(0, speed)) * .3, remaining = target * Math.exp(-Math.max(0, elapsed)/280);
  return remaining < .5 ? target : target - remaining;
}

// Port of MusicWallReflow: map complete tessellation cells, then remove the
// five-point gutter. Adjacent covers retain shared edges while a slot expands.
export function reflowFrame(frame,focus,size,gap=5){
  if(!focus)return frame;
  const coordinate=(value,lower,upper,length)=>{
    const delta=(Math.max(1,length)-(upper-lower))/2;
    if(value<=lower)return value-delta;
    if(value>=upper)return value+delta;
    return lower-delta+(value-lower)*Math.max(1,length)/(upper-lower);
  };
  const x=coordinate(frame.x,focus.x,focus.x+focus.width+gap,size.width+gap);
  const right=coordinate(frame.x+frame.width+gap,focus.x,focus.x+focus.width+gap,size.width+gap);
  const y=coordinate(frame.y,focus.y,focus.y+focus.height+gap,size.height+gap);
  const bottom=coordinate(frame.y+frame.height+gap,focus.y,focus.y+focus.height+gap,size.height+gap);
  return {...frame,x,y,width:right-x-gap,height:bottom-y-gap};
}
export function focusProgress(progress){
  if(progress<=0)return 0;if(progress>=1)return 1;
  let lower=0,upper=1;
  for(let i=0;i<18;i++){const t=(lower+upper)/2,a=1-t,x=3*a*a*t*.22+3*a*t*t*.36+t*t*t;if(x<progress)lower=t;else upper=t;}
  return 1-(1-(lower+upper)/2)**3;
}
export function reflowProgress(elapsed){
  if(elapsed<=0)return 0;if(elapsed>=520)return 1;
  const t=elapsed/1000,w=Math.sqrt(11);
  return Math.min(1,Math.max(0,1-Math.exp(-17*t)*(Math.cos(w*t)+17/w*Math.sin(w*t))));
}
export function nearestInstance(scene,index,camera,viewport){
  const tile=scene.tiles[index];if(!tile)return null;
  const cx=Math.round(((viewport.width/2-camera.x)/camera.scale-tile.x-tile.width/2)/scene.world.width);
  const cy=Math.round(((viewport.height/2-camera.y)/camera.scale-tile.y-tile.height/2)/scene.world.height);
  return {...tile,column:cx,row:cy,id:`${index}:${cx}:${cy}`,x:tile.x+cx*scene.world.width,y:tile.y+cy*scene.world.height};
}
export function wallWorkspaceMetrics(width,sidebar){
  const sidebarWidth=Math.min(260,Math.max(230,width*.25)),overlays=width<sidebarWidth+540+48;
  const leadingInset=sidebar?Math.min(sidebarWidth+24,Math.max(0,width-540-24)):0;
  const available=Math.max(240,width-leadingInset),dockWidth=Math.min(460,Math.max(240,available-40));
  return {sidebarWidth,leadingInset,overlays,headerLeading:sidebar&&!overlays?sidebarWidth+24:12,dockWidth,toolsBottom:(available-dockWidth)/2<66?94:31};
}

// Preserve a panned wall across expansion. If playback moved to another card,
// use the restored sidebar's inset to reveal that card instead of the old one.
export function restoredPlayerCamera(saved,target,viewport,leadingInset,scale){
  if(saved.sourceID===target?.id||!target)return {x:saved.x,y:saved.y};
  return {x:(viewport.width+leadingInset)/2-(target.x+target.width/2)*scale,y:viewport.height/2-(target.y+target.height/2)*scale};
}

// Native focus reserves 85% of the vertical card budget. Keep this preference
// until focus changes; live resizing only clamps it to the available viewport.
export function wallFocusSide(height){return Math.min(520,Math.max(320,(height-150)*.85));}
// Reflow moves posters outside their original spatial buckets. Invert the
// monotonic axis map before querying; otherwise panning a focused wall culls
// posters which are still on screen and reveals empty strips.
export function reflowQuery(camera,viewport,focus,size,overscan=220){
 const inverse=(value,lower,upper,length)=>{const span=upper-lower,target=Math.max(1,length),delta=(target-span)/2;if(value<=lower-delta)return value+delta;if(value>=upper+delta)return value-delta;return lower+(value-lower+delta)*span/target;};
 let left=(-camera.x-overscan)/camera.scale,right=(viewport.width-camera.x+overscan)/camera.scale,top=(-camera.y-overscan)/camera.scale,bottom=(viewport.height-camera.y+overscan)/camera.scale;
 if(focus){left=inverse(left,focus.x,focus.x+focus.width+5,size.width+5);right=inverse(right,focus.x,focus.x+focus.width+5,size.width+5);top=inverse(top,focus.y,focus.y+focus.height+5,size.height+5);bottom=inverse(bottom,focus.y,focus.y+focus.height+5,size.height+5);}
 return {left,right,top,bottom};
}
export function visibleReflowTiles(scene,camera,viewport,focus,size,overscan=220,previous=null){
 const bounds=reflowQuery(camera,viewport,focus,size,overscan);
 if(previous){const old=reflowQuery(camera,viewport,previous.focus,previous.size,overscan);bounds.left=Math.min(bounds.left,old.left);bounds.right=Math.max(bounds.right,old.right);bounds.top=Math.min(bounds.top,old.top);bounds.bottom=Math.max(bounds.bottom,old.bottom);}
 return visibleTiles(scene,{x:-bounds.left*camera.scale,y:-bounds.top*camera.scale,scale:camera.scale},{width:(bounds.right-bounds.left)*camera.scale,height:(bounds.bottom-bounds.top)*camera.scale},0);
}
