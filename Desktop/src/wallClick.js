// A poster's DOM targets change during focus/reflow. Recognize the physical
// click sequence at the stable wall surface, retaining the first song's id.
export class WallClickSequence {
  first=null;
  reset(){this.first=null;}
  click({id,x,y,time,control=false,group=false,keyboard=false},interval=500){
    const first=this.first;this.first=null;
    if(keyboard)return {type:'single'};
    if(first&&time>=first.time&&time-first.time<=interval&&Math.hypot(x-first.x,y-first.y)<=6){
      return {type:'play',id:first.id};
    }
    if(id&&!control&&!group)this.first={id,x,y,time};
    return {type:'single'};
  }
}
