import React,{useId,useState} from 'react';
import ActionButton from './ActionButton.jsx';
import {Icon} from './PlayerControls.jsx';

/** Local disclosure state; retained children preserve drafts while collapsed. */
export default function Disclosure({title,children,className='',disabled=false}){
 const [open,setOpen]=useState(false),id=useId();
 return <section className={`mv-disclosure ${className}`} data-mv-component="disclosure" data-open={open}>
  <ActionButton className="mv-disclosure-trigger" disabled={disabled} aria-expanded={open} aria-controls={id} onClick={()=>setOpen(value=>!value)}>
   <Icon name="chevronDown"/><span>{title}</span>
  </ActionButton>
  <div id={id} className="mv-disclosure-content" hidden={!open}>{children}</div>
 </section>;
}
