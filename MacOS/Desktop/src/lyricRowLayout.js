// Keep the active sentence centered while allowing every sentence to wrap.
export function lyricRowOffsets(heights,active,gap=4){
  const centers=[];let edge=0;
  for(const height of heights){centers.push(edge+height/2);edge+=height+gap;}
  const origin=centers[active]??0;
  return centers.map((center,index)=>center-origin-heights[index]/2);
}
