function visibleBounds(saved,areas,fallback){
 const valid=saved&&['x','y','width','height'].every(key=>Number.isFinite(saved[key]))&&saved.width>=160&&saved.height>=80;
 if(!areas.length)return fallback;
 const candidate=valid?saved:fallback;
 const area=areas.reduce((best,item)=>{const overlap=r=>Math.max(0,Math.min(candidate.x+candidate.width,r.x+r.width)-Math.max(candidate.x,r.x))*Math.max(0,Math.min(candidate.y+candidate.height,r.y+r.height)-Math.max(candidate.y,r.y));return overlap(item)>overlap(best)?item:best;},areas[0]);
 const width=Math.min(candidate.width,area.width),height=Math.min(candidate.height,area.height);
 return {x:Math.max(area.x,Math.min(candidate.x,area.x+area.width-width)),y:Math.max(area.y,Math.min(candidate.y,area.y+area.height-height)),width,height};
}
module.exports={visibleBounds};
