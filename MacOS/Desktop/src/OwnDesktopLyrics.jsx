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
 return <main className="own-lyrics-unlock" title={error||'解锁桌面歌词'}><ActionButton feedback="none" aria-label="解锁桌面歌词" onClick={()=>command('desktopLyricsConfig',{locked:false}).catch(error=>setError(error.message))}><Icon name="unlock"/></ActionButton></main>;
}
export default function OwnDesktopLyrics(){
 const [error,setError]=useState(''),[fit,setFit]=useState(0);const act=(name,payload)=>command(name,payload).catch(e=>setError(e.message||String(e)));
 const state=usePlayback(),clock=useClock(),ink=useRef(null),content=useRef(null),clockRef=useRef(clock);clockRef.current=clock;
 const track=state.playing||state.selected,lines=track?.lines||[];let index=-1;for(let i=0;i<lines.length;i++)if(lines[i].time!==null&&lines[i].time<=clock.time)index=i;
 const line=lines[Math.max(0,index)],next=lines[Math.max(0,index)+1],reduced=matchMedia('(prefers-reduced-motion:reduce)').matches,theme=useLyricsTheme(state.appearance);
 useEffect(()=>{command('snapshot').catch(()=>{});},[]);
 useLayoutEffect(()=>{
  const node=content.current;
  const weighted=text=>[...String(text||'')].reduce((sum,c)=>sum+(c.charCodeAt(0)>255?2:1),0);
  const candidates=[...lines,{text:track?.title||'选择一首歌曲'}].sort((a,b)=>weighted(b.text)-weighted(a.text)).slice(0,3),translations=state.showLyricsTranslation!==false?[...lines].filter(l=>l.translation).sort((a,b)=>weighted(b.translation)-weighted(a.translation)).slice(0,1):[];
  const measure=()=>{if(!node.clientWidth||!node.clientHeight)return;const vertical=state.desktopLyricsVertical,probes=candidates.map(line=>{const p=document.createElement('div');p.className='own-desktop-line';p.textContent=line.text;p.setAttribute('aria-hidden','true');p.style.cssText=`position:absolute;visibility:hidden;pointer-events:none;max-width:${node.clientWidth}px;max-height:${node.clientHeight}px;inset:0 auto auto 0`;node.append(p);return p;});let translation;
   if(translations.length){translation=document.createElement('p');translation.textContent=translations[0].translation;translation.setAttribute('aria-hidden','true');translation.style.cssText=`position:absolute;visibility:hidden;pointer-events:none;max-width:${node.clientWidth}px;max-height:${node.clientHeight}px;inset:0 auto auto 0`;node.append(translation);}
   let low=8,high=Math.min(44,Math.max(18,state.desktopLyricsFont||32));
   for(let i=0;i<12;i++){const size=(low+high)/2;node.style.setProperty('--desktop-lyrics-fit',`${size}px`);const t=translation?.getBoundingClientRect(),fits=probes.every(p=>{const r=p.getBoundingClientRect();if(p.scrollHeight>p.clientHeight+1||p.scrollWidth>p.clientWidth+1||translation&&(translation.scrollHeight>translation.clientHeight+1||translation.scrollWidth>translation.clientWidth+1))return false;return vertical?r.width+(t?.width||0)+(t?6:0)<=node.clientWidth&&Math.max(r.height,t?.height||0)<=node.clientHeight+1:r.height+(t?.height||0)+(t?6:0)<=node.clientHeight&&Math.max(r.width,t?.width||0)<=node.clientWidth+1;});if(fits)low=size;else high=size;}
   const value=Math.floor(low*4)/4;node.style.setProperty('--desktop-lyrics-fit',`${value}px`);for(const p of probes)p.remove();translation?.remove();setFit(previous=>previous===value?previous:value);
  };measure();const observer=new ResizeObserver(measure);observer.observe(node);return()=>observer.disconnect();
 },[track?.id,lines,state.desktopLyricsFont,state.showLyricsTranslation,state.desktopLyricsLocked,state.desktopLyricsVertical]);
 useEffect(()=>{let frame;const paint=()=>{const c=clockRef.current,time=c.time+(c.playing?Math.min(.25,(performance.now()-c.sampledAt)/1000):0);paintLyricSweep(ink.current,time,{reduced,wall:theme!=='light'});if(c.playing&&!reduced)frame=requestAnimationFrame(paint);};paint();return()=>cancelAnimationFrame(frame);},[line,clock.playing,clock.playing?null:clock.time,reduced,theme,fit]);
 return <main className="own-desktop-lyrics" data-own-surface="desktopLyrics" data-locked={Boolean(state.desktopLyricsLocked)} data-vertical={Boolean(state.desktopLyricsVertical)}><header><span>{track?`${track.title} · ${track.artist}`:'MiniVoice-debug'}</span><div><ActionButton aria-label={state.desktopLyricsVertical?'切换横向歌词':'切换竖向歌词'} onClick={()=>act('desktopLyricsConfig',{vertical:!state.desktopLyricsVertical})}><Icon name="styleSwitch"/></ActionButton><ActionButton aria-label="锁定桌面歌词" onClick={()=>act('desktopLyricsConfig',{locked:true})}><Icon name="lock"/></ActionButton><ActionButton aria-label="关闭桌面歌词" onClick={()=>act('desktopLyrics')}><Icon name="close"/></ActionButton></div></header>{error&&<p role="alert">{error}</p>}<div ref={content} className="own-desktop-lyrics-text"><div ref={ink} className="own-desktop-line">{line?.words?.length?line.words.map((word,i)=><span key={`${index}:${i}`} className="lyric-word" data-word-start={word.start} data-word-end={word.end??line.words[i+1]?.start??line.end??next?.time??word.start+1}>{word.text}</span>):line?.text||track?.title||'选择一首歌曲'}</div>{state.showLyricsTranslation!==false&&line?.translation&&<p>{line.translation}</p>}</div></main>;
}
