import {useDialogBoundary} from '../../../Shared/UI/src/components/useDialogBoundary.js';
import {useSurfaceMotion} from './surfaceMotion';
import React,{useRef} from 'react';
import {createPortal} from 'react-dom';

export function Modal({title,onClose,children,className='',alert=false}){
  const root=useRef(),layer=useRef();
  useSurfaceMotion(layer,true,{modal:true});
  useDialogBoundary(root,{onClose,background:()=>document.querySelector('.app'),initialFocus:'field'});
  return createPortal(<div ref={layer} className="modal-backdrop"><section ref={root} className={`name-dialog ${className}`} role={alert?'alertdialog':'dialog'} aria-modal="true" aria-label={title} tabIndex={-1}>{children}</section></div>,document.body);
}
