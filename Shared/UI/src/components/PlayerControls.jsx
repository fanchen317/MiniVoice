import React from 'react';
import ActionButton from './ActionButton.jsx';
import {paths} from './iconPaths.js';
export {paths} from './iconPaths.js';
const aliases={wallMenu:'menu',wallSearch:'search'};
export function Icon({name,filled=false}){const key=aliases[name]||name;return <svg className="mv-icon" data-icon={name} width="24" height="24" viewBox="0 0 24 24" fill={key==='play'||key==='pauseFilled'||filled?'currentColor':'none'} stroke="currentColor" strokeWidth={key==='play'||key==='pauseFilled'?0:1.7} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false"><path d={paths[key]||paths.music}/></svg>;}
export function Button({label,icon,onClick,selected,...props}){const primary=icon==='play'||icon==='pauseFilled';return <ActionButton data-playback-primary={primary||undefined} data-playback-state={primary?(icon==='pauseFilled'?'playing':'paused'):undefined} label={label} onClick={onClick} selected={selected} className={`mv-button ${selected?'selected':''}`} {...props}><Icon name={icon}/></ActionButton>;}
