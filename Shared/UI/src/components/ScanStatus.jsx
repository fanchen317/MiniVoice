import React from 'react';
import ActionButton from './ActionButton.jsx';
import {scanProgress} from './scanProgress.js';
import './scanStatus.css';
export default function ScanStatus({snapshot,onOpen,inline=false}){
 const state=scanProgress(snapshot);
 if(!state.visible)return null;
 const content=<><span className="mv-scan-copy"><strong>{state.title}</strong><small>{state.detail}</small></span><span className={`mv-scan-track ${state.percent===null&&state.running?'is-indeterminate':''}`} role="progressbar" aria-label="音乐库扫描进度" aria-valuemin={0} aria-valuemax={100} aria-valuenow={state.percent??undefined} aria-valuetext={state.title}><span style={{width:state.percent===null?'30%':`${state.percent}%`}}/></span></>;
 return inline?<div data-mv-component="scan-status" className="mv-scan-inline" role="status" aria-live="polite">{content}{snapshot.scanExecution&&<small>{snapshot.scanExecution}</small>}</div>:<ActionButton data-mv-component="scan-status" className="mv-scan-status" aria-label="查看音乐库扫描进度" onClick={onOpen}>{content}</ActionButton>;
}
