import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import {lyricRowOffsets} from './lyricRowLayout';
import {paintLyricSweep} from './lyricSweep';
import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { command, useClock, usePlayback } from './store';
import { springEasing } from './motion';
import { displayLine,kineticCharacters,kineticLayout,kineticInk,wallLyricsMetrics } from './kinetic';

const interpolation=clock=>clock.time+(clock.playing?Math.min(.24,Math.max(0,(performance.now()-clock.sampledAt)/1000)):0);
function useSize(ref){const [size,setSize]=useState({width:1,height:1});useEffect(()=>{const observer=new ResizeObserver(entries=>{const rect=entries[0].contentRect;setSize(previous=>previous.width===rect.width&&previous.height===rect.height?previous:{width:rect.width,height:rect.height});});observer.observe(ref.current);return()=>observer.disconnect();},[]);return size;}
const activeAt=(lines,time)=>{let active=-1;for(let i=0;i<lines.length;i++)if(lines[i].time!==null&&lines[i].time<=time)active=i;return active;};
export function WallLyrics({track,kinetic=false}){
  const clock=useClock(),state=usePlayback(),root=useRef(),size=useSize(root),lines=track.lyrics?.trim()?(track.lines||[]):[];
  const active=activeAt(lines,clock.time),index=Math.max(0,active),layout=wallLyricsMetrics(size.width,size.height),showTranslation=state.showLyricsTranslation!==false,reduced=document.documentElement.classList.contains('reduce-motion');
  useLayoutEffect(()=>{
    if(kinetic)return;
    const rows=[...root.current.querySelectorAll('.wall-lyric-line')];
    const current=rows.findIndex(row=>row.classList.contains('current'));
    const place=()=>{
      const heights=rows.map(row=>row.offsetHeight),offsets=lyricRowOffsets(heights,current);
      rows.forEach((row,i)=>{row.style.top='50%';row.style.transform=`translateY(${offsets[i]}px) scale(${i===current?1:.94})`;});
    };
    place();const observer=new ResizeObserver(place);rows.forEach(row=>observer.observe(row));
    return()=>observer.disconnect();
  },[kinetic,index,lines,showTranslation,size.width,size.height,layout.fontSize]);
  const clockRef=useRef(clock);clockRef.current=clock;
  useEffect(()=>{
    const el=root.current;if(!el||kinetic)return;let frame=0;
    function tick(){const now=interpolation(clockRef.current),reduced=document.documentElement.classList.contains('reduce-motion');paintLyricSweep(el.querySelector('.wall-lyric-line.current.timed-active>.lyric-content'),now,{reduced,wall:true});if(clockRef.current.playing&&!reduced)frame=requestAnimationFrame(tick);}
    tick();return()=>cancelAnimationFrame(frame);
  },[clock.playing,clock.playing?null:clock.time,index,kinetic,lines,reduced,size.width,size.height,layout.fontSize]);
  return <div ref={root} className={`wall-lyrics ${kinetic?'kinetic-mode':''}`} aria-label="歌词" style={{'--wall-lyric-font':`${layout.fontSize}px`,'--wall-lyric-row':`${layout.rowHeight}px`,'--wall-lyric-spring':springEasing(.48,.9)}}>
    {track.lyricsLoading?<div className="wall-lyrics-loading" role="status"><span className="spinner"/><span>正在加载歌词…</span></div>:!lines.length?<div className="wall-no-lyrics"><strong>{track.title}</strong><small>暂无歌词</small></div>:kinetic?<KineticLyrics track={track} size={size} showTranslation={showTranslation}/>:<div className="wall-lyric-rows">{lines.slice(Math.max(0,index-layout.visibleRadius),Math.min(lines.length,index+layout.visibleRadius+1)).map((line,offset)=>{
      const i=Math.max(0,index-layout.visibleRadius)+offset,relative=i-index,current=relative===0;line=displayLine(line,lines.slice(i+1).find(l=>l.time>line.time)?.time,track.duration);
      return <ActionButton key={`${track.id}:${i}`} className={`wall-lyric-line ${current?'current':''} ${current&&active>=0?'timed-active':''}`} style={{transform:`translateY(${relative*layout.rowHeight}px) scale(${current?1:.94})`,opacity:current?1:Math.abs(relative)===1?.5:Math.abs(relative)===2?.32:.2}} onClick={()=>line.time!==null&&command('seek',{time:line.time})}><span className="lyric-content">{line.words?.length?line.words.map((word,n)=><span className="lyric-word" key={n} data-word-start={word.start} data-word-end={word.end??line.words[n+1]?.start??line.end??lines[i+1]?.time??word.start+1}>{word.text}</span>):line.text||'•••'}</span>{showTranslation&&line.translation&&!layout.singleLine&&<small>{line.translation}</small>}</ActionButton>;
    })}</div>}
  </div>;
}
function KineticLyrics({track,size,showTranslation}){
  const clock=useClock(),ref=useRef(),lines=track.lines||[],active=activeAt(lines,clock.time),index=Math.max(0,active),line=lines[index]||{text:'',words:[]},waiting=active<0&&lines.some(l=>l.time!==null);
  const next=lines.slice(index+1).find(l=>l.time>line.time)?.time;
  const characters=useMemo(()=>kineticCharacters(displayLine(line,next,track.duration),next),[line,next,track.duration]),clockRef=useRef(clock);clockRef.current=clock;
  const height=Math.max(80,size.height*.58),reduced=document.documentElement.classList.contains('reduce-motion');
  useEffect(()=>{
    const canvas=ref.current;if(!canvas||waiting)return;const context=canvas.getContext('2d'),scale=Math.min(2,devicePixelRatio||1),width=Math.max(1,size.width-16);
    canvas.width=Math.ceil(width*scale);canvas.height=Math.ceil(height*scale);context.setTransform(scale,0,0,scale,0,0);
    const layout=kineticLayout(characters,{width,height},(text,fontSize)=>{context.font=`700 ${fontSize}px -apple-system, BlinkMacSystemFont, sans-serif`;return context.measureText(text).width;});
    let frame=0,last=-Infinity;
    function draw(now){if(now-last>=1000/30||!clockRef.current.playing){last=now;context.clearRect(0,0,width,height);const time=interpolation(clockRef.current);context.font=`700 ${layout.fontSize}px -apple-system, BlinkMacSystemFont, sans-serif`;context.textAlign='center';context.textBaseline='middle';
      characters.forEach((word,i)=>{const ink=kineticInk(word,i,time,layout.fontSize),point=layout.glyphs[i];context.save();context.globalAlpha=ink.opacity;context.translate(point.x,point.y+ink.y);context.rotate(ink.rotation);context.scale(ink.scale,ink.scale);context.fillStyle=ink.color;context.shadowColor=`rgba(0,255,255,${ink.shadow})`;context.shadowBlur=ink.shadowRadius;context.fillText(word.text,0,0);context.restore();});
    }if(clockRef.current.playing)frame=requestAnimationFrame(draw);}
    draw(performance.now());return()=>cancelAnimationFrame(frame);
  },[characters,size.width,height,clock.playing,clock.playing?null:clock.time,waiting,reduced]);
  return <div className="kinetic-lyrics"><div key={`${track.id}:${index}`} className="kinetic-main" style={{height,fontSize:Math.min(54,size.width*.09)}}>
    {waiting?<span className="kinetic-waiting" aria-label="等待歌词">•••</span>:characters.length&&!reduced?<canvas ref={ref} role="img" aria-label={line.text} style={{width:'100%',height}}/>:<span>{line.text}</span>}
    </div>{showTranslation&&!waiting&&line.translation&&<p className="kinetic-translation">{line.translation}</p>}<div className="kinetic-spacer"/>{!waiting&&<div className="kinetic-upcoming">{lines.slice(index+1,index+3).map((upcoming,i)=><div key={index+i} style={{fontSize:Math.min(30,size.width*.052),opacity:i===0?.52:.34,filter:`blur(${i===0?1.1:2.2}px)`,transform:`scale(${i===0?.96:.92})`}}>{upcoming.text}</div>)}</div>}</div>;
}
