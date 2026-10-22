import {useDialogBoundary} from './components/useDialogBoundary.js';
import React,{useRef} from 'react';
export default function Modal({title,children,onClose}){
 const ref=useRef(null);
 useDialogBoundary(ref,{onClose});
 return <div className="mv-modal-shade" onClick={onClose}><section ref={ref} tabIndex={-1} role="dialog" aria-modal="true" aria-label={title} className="mv-modal mv-glass" onClick={event=>event.stopPropagation()}><div className="mv-modal-grip"/><header><h2>{title}</h2><button aria-label="关闭弹窗" onClick={onClose}>×</button></header><div className="mv-modal-content">{children}</div></section></div>;
}
