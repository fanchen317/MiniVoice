import React,{useEffect} from 'react';
import {OwnSettings,OwnEditor} from './OwnPanels';
import {command,signals,usePlayback} from './store';
export default function OwnPanelWindow(){
 const state=usePlayback(),params=new URLSearchParams(location.search),type=params.get('panel'),style=state.interfaceStyle||'library';
 useEffect(()=>{const media=matchMedia('(prefers-color-scheme:dark)'),apply=()=>{document.documentElement.dataset.theme=state.appearance==='system'||!state.appearance?(media.matches?'dark':'light'):state.appearance;};apply();media.addEventListener('change',apply);return()=>media.removeEventListener('change',apply);},[state.appearance]);
 useEffect(()=>{document.documentElement.classList.add('own-panel-window');const close=()=>document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));signals.addEventListener('panelClose',close);return()=>signals.removeEventListener('panelClose',close);},[]);
 const close=()=>command('panelClose');
 return type==='settings'?<OwnSettings style={style} onStyle={value=>command('interfaceStyle',{value})} onClose={close}/>:<OwnEditor id={params.get('id')} style={style} onClose={close}/>;
}
