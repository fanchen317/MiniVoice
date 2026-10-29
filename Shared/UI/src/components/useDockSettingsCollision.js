import {useLayoutEffect} from 'react';
import {dockOverlapsSettings} from './dockCollision.js';
/** Content geometry owns collision; tablet/phone breakpoints do not guess it. */
export function useDockSettingsCollision(root,style){
 useLayoutEffect(()=>{
  const node=root.current,dock=node?.querySelector('.mv-wall-dock'),settings=node?.querySelector('[data-wall-control=settings]');
  if(!node||style!=='wall'||!dock||!settings)return;
  let active=true;
  node.dataset.dockGeometryReady='false';
  const measure=()=>{
   if(!active)return;
   const bounds=node.getBoundingClientRect(),button=settings.getBoundingClientRect(),safe=Number.parseFloat(getComputedStyle(node).getPropertyValue('--mv-safe-bottom'))||0;
   const resting={left:button.left,top:bounds.bottom-safe-14-button.height,width:button.width,height:button.height};
   // Chrome travel must not change the resting collision decision.
   const rect=dock.getBoundingClientRect(),bottom=parseFloat(getComputedStyle(dock).bottom)||0;
   const collision=dockOverlapsSettings({...rect.toJSON(),top:bounds.bottom-bottom-rect.height},resting);
   node.dataset.dockOverlap=String(collision);
  };
  // Width transitions produce ResizeObserver callbacks for intermediate frames.
  const observer=new ResizeObserver(measure);observer.observe(node);observer.observe(dock);observer.observe(settings);
  globalThis.addEventListener('minivoice-insets',measure);measure();
  // Resolve the initial resting/raised style before enabling transitions, avoiding a startup jump.
  settings.getBoundingClientRect();node.dataset.dockGeometryReady='true';
  return()=>{active=false;observer.disconnect();globalThis.removeEventListener('minivoice-insets',measure);delete node.dataset.dockOverlap;delete node.dataset.dockGeometryReady;};
 },[root,style]);
}
