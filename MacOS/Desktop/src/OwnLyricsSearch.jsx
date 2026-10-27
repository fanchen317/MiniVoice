import React,{useEffect,useRef,useState} from 'react';
import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import LyricsPreview from '../../../Shared/UI/src/components/LyricsPreview.jsx';
import OwnSearchBrowser from './OwnSearchBrowser.jsx';
import {command} from './store';
export default function OwnLyricsSearch({id,title,artist,duration,parse,onAudition,disabled,onApply,onError,onClose}){
 const [query,setQuery]=useState(title),[who,setWho]=useState(artist),[rows,setRows]=useState(null),[candidate,setCandidate]=useState(null),[busy,setBusy]=useState(false),[failure,setFailure]=useState(''),revision=useRef(0);
 useEffect(()=>()=>{revision.current++;},[id]);
 async function search(){if(busy||disabled)return;const serial=++revision.current;setBusy(true);setFailure('');setCandidate(null);try{const value=await command('lyricsSearch',{id,title:query,artist:who},{reportError:false});if(serial===revision.current)setRows(value.map(row=>({...row,key:row.id})));}catch(e){if(serial===revision.current){setFailure(e.message);onError(e.message);}}finally{if(serial===revision.current)setBusy(false);}}
 return <OwnSearchBrowser title="在线歌词" busy={busy} disabled={disabled} error={failure} onBack={onClose} onSearch={search} query={query} onQuery={setQuery} artist={who} onArtist={setWho} rows={rows} selected={candidate?.key} onSelect={setCandidate} footer={candidate&&<ActionButton className="own-primary" disabled={busy||disabled} onClick={()=>onApply(candidate.lyrics)}>应用到歌词草稿</ActionButton>}>{candidate&&<div className="own-candidate-preview"><h3>{candidate.title}</h3><p className="own-note">{candidate.artist} · {candidate.source}</p><LyricsPreview key={candidate.id} title="在线歌词预览" raw={candidate.lyrics} parse={parse} duration={duration} onAudition={onAudition} disabled={disabled}/></div>}</OwnSearchBrowser>;
}
