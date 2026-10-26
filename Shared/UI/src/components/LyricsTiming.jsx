import Disclosure from './Disclosure.jsx';
import ActionButton from './ActionButton.jsx';
import React,{useMemo,useState} from 'react';
import {lyricTimingRows,stampLyricLine} from '../editorTools.js';
import Slider from './Slider.jsx';
export default function LyricsTiming({raw,onChange,position=0,duration=0,active=false,playing=false,onPlay,onSeek,disabled=false,onError}){
 const rows=useMemo(()=>lyricTimingRows(raw),[raw]),[cursor,setCursor]=useState(0),[undo,setUndo]=useState(null),index=Math.min(cursor,rows.length),time=Math.max(0,position);
 function stamp(){try{const row=rows[index];if(!row)return;const after=stampLyricLine(raw,row.index,time);setUndo({raw,after,cursor:index});onChange(after);setCursor(index+1);}catch(e){onError?.(e.message);}}
 return <Disclosure className="mv-lyrics-timing" title="手动歌词打点"><p>试听歌曲，在对应歌词开始时标记。修改先保留在草稿中，保存后生效。</p><div className="mv-timing-actions"><ActionButton type="button" disabled={disabled} onClick={onPlay}>{active&&playing?'暂停试听':'播放试听'}</ActionButton><ActionButton type="button" disabled={disabled||!active||index>=rows.length} onClick={stamp}>{index<rows.length?`标记第 ${index+1} 行`:'已完成打点'}</ActionButton><ActionButton type="button" disabled={disabled||!undo||undo.after!==raw} onClick={()=>{onChange(undo.raw);setCursor(undo.cursor);setUndo(null);}}>撤销上次打点</ActionButton><ActionButton type="button" disabled={disabled} onClick={()=>{setCursor(0);setUndo(null);}}>从第一行开始</ActionButton></div><p role="status">{Math.floor(time/60)}:{(time%60).toFixed(2).padStart(5,'0')} · {rows[index]?.text||'暂无待标记歌词'}</p><Slider label="歌词试听进度" value={time} min={0} max={Math.max(1,duration)} step={.1} disabled={disabled||!active||!duration} onCommit={onSeek}/><div className="mv-timing-lines">{rows.map((row,i)=><ActionButton type="button" key={row.index} aria-current={index===i?'step':undefined} disabled={disabled} onClick={()=>{setCursor(i);setUndo(null);}}>{i+1}. {row.text}</ActionButton>)}</div></Disclosure>;
}
