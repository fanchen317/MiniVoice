import ActionButton from './ActionButton.jsx';
import React,{useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {MenuPopover} from './Menu.jsx';
export default function Choice({label,value,options,onChange,disabled=false}){
 const anchor=useRef(null),[point,setPoint]=useState(null),selected=options.find(option=>option.value===value);
 function open(){if(disabled)return;const rect=anchor.current.getBoundingClientRect();setPoint({x:rect.left,y:rect.bottom+5});}
 return <><ActionButton ref={anchor} type="button" className="mv-choice" data-mv-component="choice" aria-label={label} aria-haspopup="menu" aria-expanded={Boolean(point)} disabled={disabled} onClick={()=>point?setPoint(null):open()} onKeyDown={event=>{if(['ArrowDown','ArrowUp'].includes(event.key)){event.preventDefault();event.stopPropagation();open();}}}><span>{selected?.label||'请选择'}</span><span aria-hidden="true">⌄</span></ActionButton>{point&&createPortal(<MenuPopover className="mv-choice-menu" point={point} origin={anchor.current} label={label} onClose={()=>setPoint(null)}>{options.map(option=><ActionButton type="button" role="menuitemradio" aria-checked={option.value===value} disabled={option.disabled} key={option.value} onClick={()=>{onChange(option.value);setPoint(null);}}><span aria-hidden="true">{option.value===value?'✓':'　'}</span>{option.label}</ActionButton>)}</MenuPopover>,document.body)}</>;
}
