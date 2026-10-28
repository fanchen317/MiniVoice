/** Test the button's resting position, never its raised position, to avoid feedback loops. */
export function dockOverlapsSettings(dock,settings,gap=12){
 if(!dock||!settings||![dock.left,dock.top,dock.width,dock.height,settings.left,settings.top,settings.width,settings.height,gap].every(Number.isFinite)||dock.width<=0||dock.height<=0||settings.width<=0||settings.height<=0)return false;
 return dock.left<settings.left+settings.width+gap&&dock.left+dock.width+gap>settings.left&&dock.top<settings.top+settings.height+gap&&dock.top+dock.height+gap>settings.top;
}
