import React,{useLayoutEffect,useRef,useState} from 'react';
import {useMenu} from './useMenu.js';
import {menuPosition} from './menuModel.js';
import {useScrollThumb} from './useScrollThumb.js';
export function MenuList({children,label,version,className='',...props}){
 const root=useRef(null);useMenu(root,{version});
 return <div {...props} ref={root} role="menu" aria-label={label} data-mv-menu="list" className={className}>{children}</div>;
}
export function MenuPopover({children,label='操作菜单',point,onClose,origin,className=''}){
 const root=useRef(null),close=useRef(onClose),previous=useRef(origin||document.activeElement),[position,setPosition]=useState({left:point.x,top:point.y,visibility:'hidden'});close.current=onClose;
 useMenu(root,{autoFocus:true});useScrollThumb(root,{label:'滚动操作菜单'});
 useLayoutEffect(()=>{const node=root.current,place=()=>setPosition({...menuPosition(point,{width:node.offsetWidth,height:Math.max(node.offsetHeight,node.scrollHeight+node.offsetHeight-node.clientHeight)},{width:innerWidth,height:innerHeight}),visibility:'visible'});place();const observer=new ResizeObserver(place);observer.observe(node);const outside=event=>{if(!node.contains(event.target))close.current?.();};const key=event=>{if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();close.current?.();}if(event.key==='Tab'){event.preventDefault();event.stopImmediatePropagation();close.current?.();}};document.addEventListener('pointerdown',outside,true);window.addEventListener('keydown',key,true);window.addEventListener('resize',place);return()=>{observer.disconnect();document.removeEventListener('pointerdown',outside,true);window.removeEventListener('keydown',key,true);window.removeEventListener('resize',place);if(previous.current?.isConnected&&!document.querySelector('[aria-modal=true]'))previous.current.focus({preventScroll:true});};},[point.x,point.y]);
 return <div ref={root} role="menu" aria-label={label} data-mv-menu="popover" className={className} style={{...position,position:'fixed',overflowY:'auto'}} onClick={event=>event.stopPropagation()}>{children}</div>;
}
