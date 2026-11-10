// Predict a bounded next viewport without mounting extra React poster nodes.
export function wallArtworkPlan(cells,items,camera,viewport,frameFor=cell=>cell,{limit=48}={}){
 const ranked=cells.map(cell=>{const frame=frameFor(cell),x=camera.x+frame.x*camera.scale,y=camera.y+frame.y*camera.scale,width=frame.width*camera.scale,height=frame.height*camera.scale;
  const visible=x<viewport.width&&x+width>0&&y<viewport.height&&y+height>0;
  return {source:items[cell.index]?.artworkWall||items[cell.index]?.artwork,visible,distance:(x+width/2-viewport.width/2)**2+(y+height/2-viewport.height/2)**2};
 }).filter(entry=>entry.source).sort((a,b)=>Number(b.visible)-Number(a.visible)||a.distance-b.distance);
 return [...new Set(ranked.map(entry=>entry.source))].slice(0,limit);
}
export function anticipatedWallCamera(camera,previous){
 if(!previous||camera.scale!==previous.scale)return camera;
 const dx=camera.x-previous.x,dy=camera.y-previous.y,distance=Math.hypot(dx,dy);
 if(distance<1)return camera;
 const lead=Math.min(420,distance*2.5)/distance;
 return {...camera,x:camera.x+dx*lead,y:camera.y+dy*lead};
}
