import {useLayoutEffect} from 'react';
import {dialogViewport} from './dialogViewport.js';

/** The dialog owns these variables; the page and its playback dock retain their geometry. */
export function useDialogViewport(layer){
 useLayoutEffect(()=>{
  const node=layer.current;if(!node)return;
  const viewport=window.visualViewport;let frame=0;
  const measure=()=>{frame=0;let {top,height,keyboard}=dialogViewport(window.innerHeight,viewport,parseFloat(getComputedStyle(node).getPropertyValue('--mv-keyboard-bottom'))||0);node.style.setProperty('--mv-dialog-top',`${top}px`);node.style.setProperty('--mv-dialog-height',`${height}px`);node.dataset.visualKeyboard=String(keyboard);};
  const schedule=()=>{if(!frame)frame=requestAnimationFrame(measure);};
  const changes=new MutationObserver(schedule),workspace=node.closest('.mv-workspace');if(workspace)changes.observe(workspace,{attributes:true,attributeFilter:['style','data-table-mode']});measure();window.addEventListener('resize',schedule);window.addEventListener('minivoice-insets',schedule);viewport?.addEventListener('resize',schedule);viewport?.addEventListener('scroll',schedule);
  return()=>{changes.disconnect();cancelAnimationFrame(frame);window.removeEventListener('resize',schedule);window.removeEventListener('minivoice-insets',schedule);viewport?.removeEventListener('resize',schedule);viewport?.removeEventListener('scroll',schedule);node.style.removeProperty('--mv-dialog-top');node.style.removeProperty('--mv-dialog-height');delete node.dataset.visualKeyboard;};
 },[layer]);
}
