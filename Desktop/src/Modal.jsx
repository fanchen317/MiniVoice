import React,{useEffect,useRef} from 'react';
import {createPortal} from 'react-dom';

const stack=[];let originalInert=false;
// Native sheets suspend the main window's responder chain. Keep the same
// boundary for web forms, including playback shortcuts and nested popovers.
export function Modal({title,onClose,children,className='',alert=false}){
  const root=useRef(),close=useRef(onClose);close.current=onClose;
  useEffect(()=>{
    const node=root.current,previous=document.activeElement,app=document.querySelector('.app');
    if(!stack.length)originalInert=app?.inert||false;
    for(const modal of stack)modal.inert=true;stack.push(node);
    if(app)app.inert=true;
    const fields=()=>[...root.current.querySelectorAll('input:not([type=checkbox]):not([type=range]),textarea,[contenteditable="true"]')].filter(e=>!e.disabled&&e.getClientRects().length);
    (root.current.querySelector('[autofocus],input:not([type=checkbox])')||fields()[0]||root.current).focus();
    const key=event=>{
      if(stack.at(-1)!==node)return;
      event.stopImmediatePropagation();
      if(event.key==='Escape'){event.preventDefault();close.current?.();}
      if(event.key==='Tab'){
        const list=fields(),i=list.indexOf(document.activeElement);event.preventDefault();
        list[(i+(event.shiftKey?-1:1)+list.length)%list.length]?.focus();
      }
    };
    window.addEventListener('keydown',key,true);
    return()=>{window.removeEventListener('keydown',key,true);const index=stack.indexOf(node);if(index>=0)stack.splice(index,1);if(stack.length)stack.at(-1).inert=false;else if(app)app.inert=originalInert;previous?.isConnected&&previous.focus({preventScroll:true});};
  },[]);
  return createPortal(<div className="modal-backdrop"><section ref={root} className={`name-dialog ${className}`} role={alert?'alertdialog':'dialog'} aria-modal="true" aria-label={title} tabIndex={-1}>{children}</section></div>,document.body);
}
