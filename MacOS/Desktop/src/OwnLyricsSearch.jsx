import React,{useEffect,useRef,useState} from 'react';
import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import LyricsPreview from '../../../Shared/UI/src/components/LyricsPreview.jsx';
import CheckControl from '../../../Shared/UI/src/components/CheckControl.jsx';
import OwnSearchBrowser from './OwnSearchBrowser.jsx';
import {command} from './store';
import {formatSearchDuration,lyricsTimingLabel} from '../../../Shared/UI/src/components/searchResultModel.js';
export default function OwnLyricsSearch({id,title,artist,duration,parse,onAudition,disabled,onApply,onError,onClose}){
 const [simplified,setSimplified]=useState(true);
 const [query,setQuery]=useState(title),[who,setWho]=useState(artist),[rows,setRows]=useState(null),[candidate,setCandidate]=useState(null),[busy,setBusy]=useState(false),[failure,setFailure]=useState(''),revision=useRef(0);
 useEffect(()=>{setQuery(title);setWho(artist);search(title,artist);return()=>{revision.current++;};},[id]);
 async function search(text=query,performer=who){if(busy||disabled)return;const serial=++revision.current;setBusy(true);setFailure('');setCandidate(null);try{const value=await command('lyricsSearch',{id,title:text,artist:performer},{reportError:false});if(serial===revision.current)setRows(value.map(row=>({...row,key:row.id})));}catch(e){if(serial===revision.current){setFailure(e.message);onError(e.message);}}finally{if(serial===revision.current)setBusy(false);}}
 return <OwnSearchBrowser title="在线歌词" busy={busy} disabled={disabled} error={failure} onBack={onClose} onSearch={()=>search()} query={query} onQuery={setQuery} artist={who} onArtist={setWho} rows={rows} selected={candidate?.key} onSelect={setCandidate} footer={candidate&&<ActionButton className="own-primary" disabled={busy||disabled} onClick={()=>onApply(simplified?(candidate.simplifiedLyrics??candidate.lyrics):candidate.lyrics)}>应用到歌词草稿</ActionButton>}>{candidate&&<div className="own-candidate-preview"><CheckControl label="简体预览并应用" checked={simplified} onCheckedChange={setSimplified}/><h3>{candidate.title}</h3><dl className="mv-search-metadata"><div><dt>歌手</dt><dd>{candidate.artist||'未知歌手'}</dd></div><div><dt>专辑</dt><dd>{candidate.album||'未提供专辑'}</dd></div><div><dt>时长</dt><dd>{formatSearchDuration(candidate.duration)}</dd></div><div><dt>歌词类型</dt><dd>{lyricsTimingLabel(candidate)}{candidate.hasTranslation?' · 含翻译':''}</dd></div><div><dt>来源</dt><dd>{candidate.source}</dd></div></dl><LyricsPreview showTiming key={candidate.id} title="在线歌词预览" raw={simplified?(candidate.simplifiedLyrics??candidate.lyrics):candidate.lyrics} parse={parse} duration={duration} onAudition={onAudition} disabled={disabled}/></div>}</OwnSearchBrowser>;
}
