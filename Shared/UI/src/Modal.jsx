import ActionButton from './components/ActionButton.jsx';
import {useSurfaceMotion} from './components/useSurfaceMotion.js';
import {Icon} from './components/PlayerControls.jsx';
import ScrollRail from './components/ScrollRail.jsx';
import {useDialogBoundary} from './components/useDialogBoundary.js';
import React,{useRef} from 'react';
export default function Modal({title,children,onClose}){
 const ref=useRef(null),layer=useRef(null),scroll=useRef(null);
 useSurfaceMotion(layer,true,{modal:true});
 useDialogBoundary(ref,{onClose});
 return <div ref={layer} className="mv-modal-shade" onClick={onClose}><section ref={ref} tabIndex={-1} role="dialog" aria-modal="true" aria-label={title} className="mv-modal mv-glass" onClick={event=>event.stopPropagation()}><div className="mv-modal-grip"/><header><h2>{title}</h2><ActionButton aria-label="关闭弹窗" onClick={onClose}><Icon name="close"/></ActionButton></header><div className="mv-modal-scroll"><div ref={scroll} className="mv-modal-content">{children}</div><ScrollRail target={scroll}/></div></section></div>;
}
