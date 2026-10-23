import {useIdleCollapse} from './components/useIdleCollapse.js';
import ActionButton from './components/ActionButton.jsx';
import React from 'react';
import {Button,Icon} from './components/PlayerControls.jsx';
import Artwork from './Artwork.jsx';
import Slider from './components/Slider.jsx';
export default function WallDock({song,playing,position,hidden,blocked,onLocate,onToggle,onSkip,onQueue,onSeek,onCompact}){
 const {collapsed:compact,expand,events}=useIdleCollapse({enabled:!hidden,blocked,identity:song?.id,onChange:onCompact});
 return <section className={`mv-wall-dock mv-dock ${compact?'is-compact':''}`} aria-label="播放器" hidden={hidden} {...events}>
  <ActionButton type="button" className="wp-dock-meter" aria-label="展开播放条" hidden={!compact} onClick={expand}>{playing?<span className="wp-bars is-playing" aria-hidden="true"><i/><i/><i/></span>:<Icon name="play"/>}</ActionButton>
  <div className="wp-dock-content" hidden={compact}><div className="wp-dock-row"><ActionButton type="button" className="mv-now" onClick={onLocate}>{song?.artwork?<Artwork src={song.artwork}/>:<span className="mv-small-art">♫</span>}<span><strong>{song?.title||'选择一首歌曲'}</strong><span>{song?.artist||'MiniVoice'}</span></span></ActionButton><div className="wp-dock-controls"><Button label="上一首" icon="prev" onClick={()=>onSkip(-1)} disabled={!song}/><Button label={playing?'暂停':'播放'} icon={playing?'pauseFilled':'play'} onClick={onToggle} disabled={!song}/><Button label="下一首" icon="next" onClick={()=>onSkip(1)} disabled={!song}/><Button label="播放队列" icon="queue" onClick={onQueue}/></div></div><Slider label="播放进度" min={0} max={Math.max(1,song?.duration||1)} step={100} value={position} resetKey={song?.id} disabled={!song?.duration} onCommit={onSeek}/></div>
 </section>;
}
