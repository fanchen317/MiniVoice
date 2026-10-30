// A viewport-sized backing with a small guard band. Its dimensions never grow
// with the library or distance travelled; rebase all local coordinates atomically.
export const WALL_PAN_GUARD=256;
export const WALL_PAN_REBASE=180;
export function rasterCamera(previous,camera){
 return !previous||previous.scale!==camera.scale||Math.abs(camera.x-previous.x)>WALL_PAN_REBASE||Math.abs(camera.y-previous.y)>WALL_PAN_REBASE?{...camera}:previous;
}
export function projectWallFrame(frame,camera,guard=0){
 return {x:guard+camera.x+frame.x*camera.scale,y:guard+camera.y+frame.y*camera.scale,width:frame.width*camera.scale,height:frame.height*camera.scale};
}
