import React from 'react';
import {createRoot} from 'react-dom/client';
import KineticLyrics from '../src/components/KineticLyrics.jsx';
// Same phrase, timestamps, viewport and background isolate host rendering differences.
const text='柳叶桨溅桃花浪 汀州里鹤眺远方';
const lines=[{time:0,text,words:[...text].map((text,i)=>({text,start:i*.4,end:(i+1)*.4}))},{time:8,text:'饮一盏岁月留香 唱一曲往事飞扬'}];
window.renderKineticComparison=({time=3,width=844,height=260}={})=>{
 createRootOnce.render(<div style={{display:'flex',gap:16,padding:16}}>{['iOS','Android'].map(host=><section key={host} style={{width,flexShrink:0}}><p style={{color:'white',font:'16px system-ui'}}>{host} · {time.toFixed(3)}s</p><div style={{width,height,background:'#35353b'}}><KineticLyrics lines={lines} time={time} duration={12} showSeam={host!=='iOS'}/></div></section>)}</div>);
};
const createRootOnce=createRoot(document.getElementById('root'));
window.renderKineticComparison();
