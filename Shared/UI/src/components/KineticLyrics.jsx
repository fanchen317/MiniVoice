import './kineticLyrics.css';
import {samplePlaybackClock,playbackTime} from './playbackClock.js';
import React,{useEffect,useLayoutEffect,useMemo,useRef,useState} from 'react';
import {normalizeLyrics,displayLine} from './lyricPresentation.js';
import {createLyricTimeline,lyricTimelineIndex} from './lyricTimeline.js';
import {kineticCharacters,kineticLayout,paintKineticPhrase,kineticRasterScale} from './kineticModel.js';
/** Controlled lyrics/time; only canvas size and motion preferences are local. */
export default function KineticLyrics({lines:source,time=0,duration=0,playing=false,showTranslation=true,showSeam=false}){
 const root=useRef(null),canvas=useRef(null),clock=useRef({time,playing,sampledAt:performance.now()}),[size,setSize]=useState({width:1,height:1}),[reduced,setReduced]=useState(false);
 const lines=useMemo(()=>normalizeLyrics(source),[source]),timeline=useMemo(()=>createLyricTimeline(lines),[lines]),active=lyricTimelineIndex(timeline,time);
 const index=Math.max(0,active),line=lines[index]||{text:'',words:[]},next=useMemo(()=>lines.slice(index+1).find(row=>row.time>line.time)?.time,[lines,index,line.time]),waiting=active<0&&timeline.length>0;
 const characters=useMemo(()=>kineticCharacters(displayLine(line,next,duration),next),[line,next,duration]);
 clock.current=samplePlaybackClock(clock.current,time,playing,performance.now());
 useLayoutEffect(()=>{const node=root.current,measure=()=>setSize(previous=>previous.width===node.clientWidth&&previous.height===node.clientHeight?previous:{width:node.clientWidth,height:node.clientHeight});measure();const observer=new ResizeObserver(measure);observer.observe(node);return()=>observer.disconnect();},[]);
 useEffect(()=>{const media=matchMedia('(prefers-reduced-motion:reduce)'),update=()=>setReduced(media.matches||document.documentElement.classList.contains('reduce-motion')),observer=new MutationObserver(update);update();media.addEventListener('change',update);observer.observe(document.documentElement,{attributes:true,attributeFilter:['class']});return()=>{media.removeEventListener('change',update);observer.disconnect();};},[]);
 const translated=showTranslation&&!waiting&&Boolean(line.translation),upcomingCount=size.height>=260?2:size.height>=130?1:0;
 const translationFont=Math.min(25,Math.max(12,Math.min(size.width*.042,Math.sqrt(Math.max(1,size.width-36)*size.height*.24/(Math.max(1,[...(line.translation||'')].length)*1.55)))));
 const height=Math.max(30,size.height*(translated?.44:.58)),upcomingFont=Math.max(12,Math.min(30,(size.height-height-(translated?34:0))/Math.max(1,upcomingCount)/1.65));
 useEffect(()=>{
  const node=canvas.current;if(!node||waiting||reduced||!characters.length)return;
  const ctx=node.getContext('2d');if(!ctx)return;const scale=kineticRasterScale(devicePixelRatio,showSeam),width=Math.max(1,size.width);node.width=Math.ceil(width*scale);node.height=Math.ceil(height*scale);ctx.setTransform(scale,0,0,scale,0,0);
  const layout=kineticLayout(characters,{width,height},(text,font)=>{ctx.font=`700 ${font}px system-ui,sans-serif`;return ctx.measureText(text).width;},{reference:showSeam});let frame=0;
  const draw=now=>{ctx.clearRect(0,0,width,height);const sample=clock.current,t=playbackTime(sample,now);ctx.font=`700 ${layout.fontSize}px system-ui,sans-serif`;ctx.textAlign='center';ctx.textBaseline='middle';paintKineticPhrase(ctx,characters,layout,t,width,height,{showSeam});if(clock.current.playing)frame=requestAnimationFrame(draw);};draw(performance.now());return()=>cancelAnimationFrame(frame);
 },[characters,size.width,height,playing,playing?null:time,waiting,reduced,showSeam]);
 return <div ref={root} className="mv-kinetic-lyrics" data-mv-component="kinetic-lyrics" aria-label="大字歌词">{!lines.length?<p>暂无歌词</p>:<><div className="mv-kinetic-main" style={{height,fontSize:Math.min(58,Math.max(24,size.width*.095))}}>{waiting?<span>•••</span>:characters.length&&!reduced?<canvas ref={canvas} role="img" aria-label={line.text} style={{width:'100%',height}}/>:<span>{line.text}</span>}</div>{showTranslation&&!waiting&&line.translation&&<p className="mv-kinetic-translation" style={{fontSize:translationFont}}><span key={`${line.time}:${line.translation}`}>{line.translation}</span></p>}<div className="mv-kinetic-upcoming" style={{fontSize:upcomingFont}}>{lines.slice(index+1,index+1+upcomingCount).map((row,i)=><div key={`${row.time}:${i}`}>{row.text}</div>)}</div></>}</div>;
}
