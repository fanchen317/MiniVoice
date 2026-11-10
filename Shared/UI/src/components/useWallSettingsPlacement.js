import {useLayoutEffect,useRef} from 'react';
import {wallSettingsPlacement} from './wallSettingsPlacement.js';

/** Anchor coordinates belong to the viewport layer, outside the recessed scene. */
export function useWallSettingsPlacement(layer,panel,anchor,search,enabled){
 const ownsGeometry=useRef(false);
 useLayoutEffect(()=>{
  const node=layer.current,sheet=panel.current,button=anchor?.current,searchControl=search?.current;
  // A reused Modal can become another variant without unmounting. Clear only
  // our geometry in the new effect; unmount cleanup must leave exit sampling intact.
  if(!enabled){if(ownsGeometry.current&&sheet)for(const key of ['width','right','bottom','height','max-height'])sheet.style.removeProperty(key);ownsGeometry.current=false;return;}
  if(!node||!sheet||!button)return;
  ownsGeometry.current=true;
  let frame=0;
  // Wall chrome uses independent scale/translate for feedback and travel.
  // Its offset layout plus static positioning transforms (search's -50% Y)
  // defines the resting anchors, even while the search container is closing.
  const controlRect=element=>{
   let left=0,top=0;
   for(let current=element;current;current=current.offsetParent){
    const matrix=new DOMMatrixReadOnly(getComputedStyle(current).transform);
    left+=current.offsetLeft+(current.offsetParent?.clientLeft||0)+matrix.m41;
    top+=current.offsetTop+(current.offsetParent?.clientTop||0)+matrix.m42;
   }
   for(let parent=element.parentElement;parent;parent=parent.parentElement){left-=parent.scrollLeft;top-=parent.scrollTop;}
   return {top,right:left+element.offsetWidth,bottom:top+element.offsetHeight};
  };
  const measure=()=>{
   frame=0;const bounds=node.getBoundingClientRect(),target=controlRect(button),topControl=searchControl&&controlRect(searchControl),style=getComputedStyle(node);
   const value=wallSettingsPlacement({width:bounds.width,height:bounds.height,gap:parseFloat(style.getPropertyValue('--mv-dialog-gap'))||12,padding:Object.fromEntries(['top','right','bottom','left'].map(side=>[side,parseFloat(style.getPropertyValue(`padding-${side}`))||0])),anchor:{right:target.right-bounds.left,bottom:target.bottom-bounds.top},search:topControl?{top:topControl.top-bounds.top}:undefined});
   for(const key of ['width','right','bottom','height','maxHeight']){const next=`${value[key]}px`;if(sheet.style[key]!==next)sheet.style[key]=next;}
  };
  const schedule=()=>{if(!frame)frame=requestAnimationFrame(measure);};
  const settled=event=>{if(['bottom','top','right','left'].includes(event.propertyName))schedule();};
  const observer=new ResizeObserver(schedule);observer.observe(node);observer.observe(button);if(searchControl)observer.observe(searchControl);
  const workspace=node.closest('.mv-workspace'),changes=new MutationObserver(schedule);if(workspace)changes.observe(workspace,{attributes:true,attributeFilter:['data-dock-overlap','data-dialog-placement','style']});
  window.addEventListener('resize',schedule);window.addEventListener('minivoice-insets',schedule);button.addEventListener('transitionend',settled);
  const visual=window.visualViewport;visual?.addEventListener('resize',schedule);visual?.addEventListener('scroll',schedule);
  measure();
  return()=>{cancelAnimationFrame(frame);observer.disconnect();changes.disconnect();window.removeEventListener('resize',schedule);window.removeEventListener('minivoice-insets',schedule);button.removeEventListener('transitionend',settled);visual?.removeEventListener('resize',schedule);visual?.removeEventListener('scroll',schedule);};
 },[layer,panel,anchor,search,enabled]);
}
