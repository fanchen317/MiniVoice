import ActionButton from './ActionButton.jsx';
import React,{useLayoutEffect,useRef} from 'react';
import {Icon} from './PlayerControls.jsx';
import ScrollRail from './ScrollRail.jsx';
/** Shared content shell. Desktop supplies a side rail; touch uses horizontal tabs. */
export default function PanelFrame({title,tabs,tab,onTab,onClose,busy,children,footer,input='keyboard-mouse'}){
 const scroll=useRef(null),positions=useRef({});
 useLayoutEffect(()=>{if(scroll.current)scroll.current.scrollTop=positions.current[tab]||0;},[tab]);
 return <div className="mv-panel-frame" data-mv-component="panel" aria-busy={busy||undefined}><header className="mv-panel-heading"><h2>{title}</h2><ActionButton type="button" aria-label={`关闭${title}`} disabled={busy} onClick={onClose}><Icon name="close"/></ActionButton></header><div className="mv-panel-body"><nav aria-label={`${title}分类`}>{tabs.map(item=><ActionButton type="button" key={item.id} aria-current={tab===item.id?'page':undefined} onClick={()=>{positions.current[tab]=scroll.current?.scrollTop||0;onTab(item.id);}}>{item.icon&&<Icon name={item.icon}/>}<span>{item.label}</span></ActionButton>)}</nav><div className="mv-panel-scroll"><div ref={scroll} className="mv-panel-content">{children}</div><ScrollRail target={scroll} input={input}/></div></div>{footer&&<footer className="mv-panel-footer">{footer}</footer>}</div>;
}
