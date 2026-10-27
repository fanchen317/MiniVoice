import {useSheetDrag} from './components/useSheetDrag.js';
import ActionButton from './components/ActionButton.jsx';
import {useSurfaceMotion} from './components/useSurfaceMotion.js';
import {Icon} from './components/PlayerControls.jsx';
import ScrollRail from './components/ScrollRail.jsx';
import {useDialogBoundary} from './components/useDialogBoundary.js';
import React,{useRef} from 'react';
export default function Modal({title,children,onClose,expandable=false}){
 const ref=useRef(null),layer=useRef(null),scroll=useRef(null);
 const expanded=useRef(false);
 const setExpanded=value=>{expanded.current=value;if(ref.current){ref.current.dataset.sheetExpanded=String(value);ref.current.querySelector('.mv-modal-grip')?.setAttribute('aria-expanded',String(value));}};
 const grip=useSheetDrag(ref,onClose,title,{expandable,get expanded(){return expanded.current},onExpandedChange:setExpanded});
 useSurfaceMotion(layer,true,{modal:true});
 useDialogBoundary(ref,{onClose});
 return <div ref={layer} className="mv-modal-shade" onClick={onClose}><section ref={ref} tabIndex={-1} role="dialog" aria-modal="true" aria-label={title} className="mv-modal mv-glass" data-sheet-resizable={expandable} data-sheet-expanded={expanded.current} onClick={event=>event.stopPropagation()}><ActionButton className="mv-modal-grip" data-mv-component="sheet-handle" aria-expanded={expandable?expanded.current:undefined} aria-label={expandable?'向上展开或向下收起弹窗':'拖动关闭弹窗'} feedback="none" haptic={false} {...grip}><span/></ActionButton><header><h2>{title}</h2><ActionButton aria-label="关闭弹窗" onClick={onClose}><Icon name="close"/></ActionButton></header><div className="mv-modal-scroll"><div ref={scroll} className="mv-modal-content">{children}</div>{!expandable&&<ScrollRail target={scroll}/>}</div></section></div>;
}
