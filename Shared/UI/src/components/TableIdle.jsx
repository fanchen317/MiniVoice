import React,{useEffect,useState} from 'react';
import {Icon} from './PlayerControls.jsx';
import './tableIdle.css';
export default function TableIdle(){
 const [now,setNow]=useState(()=>new Date());
 useEffect(()=>{const update=()=>{const next=new Date();setNow(previous=>previous.getMinutes()===next.getMinutes()&&previous.toDateString()===next.toDateString()?previous:next);};const timer=setInterval(update,1000);document.addEventListener('visibilitychange',update);return()=>{clearInterval(timer);document.removeEventListener('visibilitychange',update);};},[]);
 return <section className="mv-table-idle" data-mv-component="table-idle" data-idle-mode="clock" aria-label="半折空闲页面">
  <div className="mv-idle-orb" aria-hidden="true"/>
  <div className="mv-idle-content"><span className="mv-idle-brand"><Icon name="music"/> MiniVoice · 留白时刻</span>
   <><time className="mv-idle-clock" dateTime={now.toISOString()}>{now.toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit',hour12:false})}</time><span className="mv-idle-date">{now.toLocaleDateString('zh-CN',{month:'long',day:'numeric',weekday:'long'})}</span></>
   <h2>让音乐慢慢开始</h2><p>从下方选择一首歌，留一点时间给自己。</p>
  </div>
 </section>;
}
