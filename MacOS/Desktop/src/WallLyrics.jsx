import React from 'react';
import KineticLyrics from '../../../Shared/UI/src/components/KineticLyrics.jsx';
import ScrollingLyrics from '../../../Shared/UI/src/components/ScrollingLyrics.jsx';
import {command,useClock,usePlayback} from './store';

export function WallLyrics({track,kinetic=false}){
 const clock=useClock(),state=usePlayback();
 const lines=track.lyrics?.trim()?(track.lines||[]):[],showTranslation=state.showLyricsTranslation!==false;
 if(!lines.length&&(track.lyricsLoading||state.preparing))return <div className="wall-lyrics" aria-label="歌词"/>;
 return kinetic?<div className="wall-lyrics kinetic-mode"><KineticLyrics showSeam key={track.id} lines={lines} time={clock.time} duration={track.duration} playing={clock.playing} showTranslation={showTranslation}/></div>:<ScrollingLyrics className="wall-lyrics" lineClass="wall-lyric-line" lines={lines} time={clock.time} duration={track.duration} playing={clock.playing} showTranslation={showTranslation} onSeek={time=>command('seek',{time})}/>;
}
