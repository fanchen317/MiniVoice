import React,{useEffect} from 'react';
import {OwnSettings,OwnEditor} from './OwnPanels';
import {command,signals,usePlaybackSelector} from './store';
export default function OwnPanelWindow(){
 const appearance=usePlaybackSelector(state=>state.appearance),style=usePlaybackSelector(state=>state.interfaceStyle||'library'),params=new URLSearchParams(location.search),type=params.get('panel');
 useEffect(()=>{const media=matchMedia('(prefers-color-scheme:dark)'),apply=()=>{document.documentElement.dataset.theme=appearance==='system'||!appearance?(media.matches?'dark':'light'):appearance;};apply();media.addEventListener('change',apply);return()=>media.removeEventListener('change',apply);},[appearance]);
 useEffect(()=>{document.documentElement.classList.add('own-panel-window');const close=()=>document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));signals.addEventListener('panelClose',close);return()=>signals.removeEventListener('panelClose',close);},[]);
 const close=()=>command('panelClose');
 return type==='settings'?<OwnSettings style={style} onStyle={value=>command('interfaceStyle',{value})} onClose={close}/>:<OwnEditor id={params.get('id')} style={style} onClose={close}/>;
}
