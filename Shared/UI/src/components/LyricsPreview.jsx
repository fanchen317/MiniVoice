import React,{useEffect,useRef,useState} from 'react';
import ActionButton from './ActionButton.jsx';
import Slider from './Slider.jsx';
/** Draft-only rendering. Parsing and optional audio audition are injected by the page. */
export default function LyricsPreview({raw,parse,title='歌词预览',duration=0,onAudition,disabled=false}){
 const [lines,setLines]=useState([]),[time,setTime]=useState(0),[busy,setBusy]=useState(false),[error,setError]=useState(''),view=useRef(null);
 useEffect(()=>{let cancelled=false;setBusy(true);setError('');const timer=setTimeout(()=>Promise.resolve(parse(raw)).then(value=>{if(cancelled)return;if(!Array.isArray(value))throw Error('歌词预览数据无效');setLines(value);}).catch(error=>{if(!cancelled)setError(error.message);}).finally(()=>{if(!cancelled)setBusy(false);}),120);return()=>{cancelled=true;clearTimeout(timer);};},[raw,parse]);
 let active=-1;for(let i=0;i<lines.length;i++)if(lines[i].ms>=0&&lines[i].ms<=time*1000)active=i;
 useEffect(()=>{const list=view.current,row=list?.querySelector('[data-active=true]');if(row)list.scrollTop+=row.getBoundingClientRect().top-list.getBoundingClientRect().top-list.clientHeight/2+row.clientHeight/2;},[active]);
 const end=Math.max(1,duration,...lines.map(line=>Math.max(0,line.ms)/1000+4));
 return <section className="mv-lyrics-preview" data-mv-component="lyrics-preview" aria-label={title} aria-busy={busy}><header><strong>{title}</strong><span>{Math.floor(time/60)}:{String(Math.floor(time%60)).padStart(2,'0')}</span>{onAudition&&<ActionButton disabled={disabled||!duration} onClick={()=>Promise.resolve(onAudition(time)).catch(error=>setError(error.message))}>试听此处</ActionButton>}</header><Slider label={`${title}时间`} min={0} max={end} step={.1} value={time} onValueChange={setTime}/>{error&&<p role="alert">{error}</p>}<div ref={view} className="mv-preview-lines">{lines.length?lines.map((line,index)=><ActionButton key={`${line.ms}:${index}`} data-active={active===index} onClick={()=>setTime(Math.max(0,line.ms)/1000)}><span>{line.text}</span>{line.translation&&<small>{line.translation}</small>}</ActionButton>):<p>{busy?'正在生成预览…':'暂无可预览歌词'}</p>}</div></section>;
}
