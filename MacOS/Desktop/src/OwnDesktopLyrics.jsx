import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import React,{useEffect,useLayoutEffect,useRef,useState} from 'react';
import {command,usePlayback,useClock} from './store';
import {Icon} from './components';
import {paintLyricSweep} from './lyricSweep';
function useLyricsTheme(appearance){
 const [dark,setDark]=useState(()=>matchMedia('(prefers-color-scheme:dark)').matches);
 useEffect(()=>{const media=matchMedia('(prefers-color-scheme:dark)'),update=()=>setDark(media.matches);media.addEventListener('change',update);return()=>media.removeEventListener('change',update);},[]);
 const theme=appearance==='light'?'light':appearance==='system'?(dark?'dark':'light'):'dark';
 useEffect(()=>{document.documentElement.dataset.theme=theme;},[theme]);return theme;
}
export function DesktopLyricsUnlock(){
 const state=usePlayback(),[error,setError]=useState('');useLyricsTheme(state.appearance);
 useEffect(()=>{command('snapshot').catch(()=>{});},[]);
 return <main className="own-lyrics-unlock" title={error||'解锁桌面歌词'}><ActionButton aria-label="解锁桌面歌词" onClick={()=>command('desktopLyricsConfig',{locked:false}).catch(error=>setError(error.message))}><Icon name="unlock"/></ActionButton></main>;
}
export default function OwnDesktopLyrics(){
 const [error,setError]=useState(''),[fit,setFit]=useState(0);const act=(name,payload)=>command(name,payload).catch(e=>setError(e.message||String(e)));
 const state=usePlayback(),clock=useClock(),ink=useRef(null),content=useRef(null),clockRef=useRef(clock);clockRef.current=clock;
 const track=state.playing||state.selected,lines=track?.lines||[];let index=-1;for(let i=0;i<lines.length;i++)if(lines[i].time!==null&&lines[i].time<=clock.time)index=i;
 const line=lines[Math.max(0,index)],next=lines[Math.max(0,index)+1],reduced=matchMedia('(prefers-reduced-motion:reduce)').matches,theme=useLyricsTheme(state.appearance);
 useEffect(()=>{command('snapshot').catch(()=>{});},[]);
 useLayoutEffect(()=>{
  const node=content.current;
  const measure=()=>{const main=ink.current,translation=node.querySelector('p');if(!node.clientWidth||!node.clientHeight)return;let low=8,high=state.desktopLyricsFont||32;
   for(let i=0;i<12;i++){const size=(low+high)/2;node.style.setProperty('--desktop-lyrics-fit',`${size}px`);const vertical=state.desktopLyricsVertical,total=vertical?main.scrollWidth+(translation?translation.scrollWidth+6:0):main.scrollHeight+(translation?translation.scrollHeight+6:0);if(vertical?total<=node.clientWidth&&main.scrollHeight<=node.clientHeight+1:total<=node.clientHeight&&main.scrollWidth<=node.clientWidth+1)low=size;else high=size;}
   node.style.setProperty('--desktop-lyrics-fit',`${low}px`);setFit(previous=>Math.abs(previous-low)<.05?previous:low);
  };measure();const observer=new ResizeObserver(measure);observer.observe(node);return()=>observer.disconnect();
 },[line,state.desktopLyricsFont,state.showLyricsTranslation,state.desktopLyricsLocked,state.desktopLyricsVertical]);
 useEffect(()=>{let frame;const paint=()=>{const c=clockRef.current,time=c.time+(c.playing?Math.min(.25,(performance.now()-c.sampledAt)/1000):0);paintLyricSweep(ink.current,time,{reduced,wall:theme!=='light'});if(c.playing&&!reduced)frame=requestAnimationFrame(paint);};paint();return()=>cancelAnimationFrame(frame);},[line,clock.playing,clock.playing?null:clock.time,reduced,theme,fit]);
 return <main className="own-desktop-lyrics" data-own-surface="desktopLyrics" data-locked={Boolean(state.desktopLyricsLocked)} data-vertical={Boolean(state.desktopLyricsVertical)}><header><span>{track?`${track.title} · ${track.artist}`:'MiniVoice-debug'}</span><div><ActionButton aria-label={state.desktopLyricsVertical?'切换横向歌词':'切换竖向歌词'} onClick={()=>act('desktopLyricsConfig',{vertical:!state.desktopLyricsVertical})}><Icon name="styleSwitch"/></ActionButton><ActionButton aria-label="锁定桌面歌词" onClick={()=>act('desktopLyricsConfig',{locked:true})}><Icon name="lock"/></ActionButton><ActionButton aria-label="关闭桌面歌词" onClick={()=>act('desktopLyrics')}><Icon name="close"/></ActionButton></div></header>{error&&<p role="alert">{error}</p>}<div ref={content} className="own-desktop-lyrics-text"><div ref={ink} className="own-desktop-line">{line?.words?.length?line.words.map((word,i)=><span key={`${index}:${i}`} className="lyric-word" data-word-start={word.start} data-word-end={word.end??line.words[i+1]?.start??line.end??next?.time??word.start+1}>{word.text}</span>):line?.text||track?.title||'选择一首歌曲'}</div>{state.showLyricsTranslation!==false&&line?.translation&&<p>{line.translation}</p>}</div></main>;
}
