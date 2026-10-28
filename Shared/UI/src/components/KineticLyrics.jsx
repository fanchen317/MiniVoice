import React,{useEffect,useLayoutEffect,useMemo,useRef,useState} from 'react';
import {normalizeLyrics,displayLine} from './lyricPresentation.js';
import {kineticCharacters,kineticLayout,kineticInk} from './kineticModel.js';
/** Controlled lyrics/time; only canvas size and motion preferences are local. */
export default function KineticLyrics({lines:source,time=0,duration=0,playing=false,showTranslation=true}){
 const root=useRef(null),canvas=useRef(null),clock=useRef({time,playing,sampledAt:performance.now()}),[size,setSize]=useState({width:1,height:1}),[reduced,setReduced]=useState(false);
 const lines=useMemo(()=>normalizeLyrics(source),[source]);let active=-1;for(let i=0;i<lines.length;i++)if(lines[i].time!==null&&lines[i].time<=time)active=i;
 const index=Math.max(0,active),line=lines[index]||{text:'',words:[]},next=lines.slice(index+1).find(row=>row.time>line.time)?.time,waiting=active<0&&lines.some(row=>row.time!==null);
 const characters=useMemo(()=>kineticCharacters(displayLine(line,next,duration),next),[line,next,duration]);
 if(clock.current.time!==time||clock.current.playing!==playing)clock.current={time,playing,sampledAt:performance.now()};
 useLayoutEffect(()=>{const node=root.current,measure=()=>setSize(previous=>previous.width===node.clientWidth&&previous.height===node.clientHeight?previous:{width:node.clientWidth,height:node.clientHeight});measure();const observer=new ResizeObserver(measure);observer.observe(node);return()=>observer.disconnect();},[]);
 useEffect(()=>{const media=matchMedia('(prefers-reduced-motion:reduce)'),update=()=>setReduced(media.matches||document.documentElement.classList.contains('reduce-motion')),observer=new MutationObserver(update);update();media.addEventListener('change',update);observer.observe(document.documentElement,{attributes:true,attributeFilter:['class']});return()=>{media.removeEventListener('change',update);observer.disconnect();};},[]);
 const translated=showTranslation&&!waiting&&Boolean(line.translation),upcomingCount=size.height>=260?2:size.height>=130?1:0;
 const height=Math.max(30,size.height*(translated?.52:.58)),upcomingFont=Math.max(12,Math.min(30,(size.height-height-(translated?34:0))/Math.max(1,upcomingCount)/1.65));
 useEffect(()=>{
  const node=canvas.current;if(!node||waiting||reduced||!characters.length)return;
  const ctx=node.getContext('2d');if(!ctx)return;const scale=Math.min(2,devicePixelRatio||1),width=Math.max(1,size.width);node.width=Math.ceil(width*scale);node.height=Math.ceil(height*scale);ctx.setTransform(scale,0,0,scale,0,0);
  const layout=kineticLayout(characters,{width,height},(text,font)=>{ctx.font=`700 ${font}px system-ui,sans-serif`;return ctx.measureText(text).width;});let frame=0,last=-Infinity;
  const draw=now=>{if(now-last>=1000/30||!clock.current.playing){last=now;ctx.clearRect(0,0,width,height);const sample=clock.current,t=sample.time+(sample.playing?Math.min(.45,(now-sample.sampledAt)/1000):0);ctx.font=`700 ${layout.fontSize}px system-ui,sans-serif`;ctx.textAlign='center';ctx.textBaseline='middle';characters.forEach((char,i)=>{const ink=kineticInk(char,i,t,layout.fontSize),point=layout.glyphs[i];ctx.save();ctx.globalAlpha=ink.opacity;ctx.translate(point.x,point.y+ink.y);ctx.rotate(ink.rotation);ctx.scale(ink.scale,ink.scale);ctx.fillStyle=ink.color;ctx.shadowColor=`rgba(0,255,255,${ink.shadow})`;ctx.shadowBlur=ink.shadowRadius;ctx.fillText(char.text,0,0);ctx.restore();});}if(clock.current.playing)frame=requestAnimationFrame(draw);};draw(performance.now());return()=>cancelAnimationFrame(frame);
 },[characters,size.width,height,playing,playing?null:time,waiting,reduced]);
 return <div ref={root} className="mv-kinetic-lyrics" data-mv-component="kinetic-lyrics" aria-label="大字歌词">{!lines.length?<p>暂无歌词</p>:<><div className="mv-kinetic-main" style={{height}}>{waiting?<span>•••</span>:characters.length&&!reduced?<canvas ref={canvas} role="img" aria-label={line.text} style={{width:'100%',height}}/>:<span>{line.text}</span>}</div>{showTranslation&&!waiting&&line.translation&&<p className="mv-kinetic-translation">{line.translation}</p>}<div className="mv-kinetic-upcoming" style={{fontSize:upcomingFont}}>{lines.slice(index+1,index+1+upcomingCount).map((row,i)=><div key={`${row.time}:${i}`}>{row.text}</div>)}</div></>}</div>;
}
