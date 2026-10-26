import Disclosure from '../../../Shared/UI/src/components/Disclosure.jsx';
import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import {usePopoverPosition} from './usePopoverPosition';
import React,{useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {command,usePlayback} from './store';
import {Icon,IconButton} from './components';
import {backgroundTaskState} from './backgroundTaskState';

export function BackgroundTasks(){
  const state=usePlayback(),tasks=state.tasks||{};
  const [open,setOpen]=useState(false),[hideScan,setHideScan]=useState(false),[unread,setUnread]=useState(false);
  const root=useRef(),panel=useRef(),previous=useRef(state.importing);
  const position=usePopoverPosition(root,panel,open);
  const {active,hasScan,hasRecords,failed}=backgroundTaskState(state,hideScan);
  const canClear=Boolean((hasScan&&!state.importing)||(state.jobs||[]).some(job=>job.finished)||tasks.notice||(tasks.modelStatus&&!tasks.downloadingModel));
  const action=(operation,id)=>command('tasks',{operation,id});
  useEffect(()=>{
    if(state.importing)setHideScan(false);
    if(previous.current&&!state.importing)setUnread(!open);
    previous.current=state.importing;
  },[state.importing,open]);
  useEffect(()=>{
    if(!open)return;
    setUnread(false);
    if(tasks.hasUnread)action('read');
  },[open,tasks.hasUnread]);
  useEffect(()=>{
    if(!open)return;
    const outside=e=>{if(!root.current?.contains(e.target)&&!panel.current?.contains(e.target))setOpen(false);};
    const key=e=>{if(e.key==='Escape'){e.preventDefault();e.stopImmediatePropagation();setOpen(false);root.current?.querySelector('button')?.focus();}};
    window.addEventListener('pointerdown',outside,true);window.addEventListener('keydown',key,true);
    return()=>{window.removeEventListener('pointerdown',outside,true);window.removeEventListener('keydown',key,true);};
  },[open]);
  useEffect(()=>{
    if(open&&!active&&!hasRecords)setOpen(false);
  },[open,active,hasRecords]);
  const highlighted=Boolean(active||tasks.hasUnread||unread);
  if(!open&&!active&&!hasRecords)return null;
  return <span ref={root} className="background-tasks-anchor" data-busy={active>0} data-unread={highlighted} data-failed={failed}>
    <IconButton label={active?`后台任务：${active} 项进行中`:'后台任务'} active={open||highlighted} aria-expanded={open} aria-haspopup="dialog" onClick={()=>setOpen(value=>!value)}><Icon name="tasks"/></IconButton>
    {open&&createPortal(<section ref={panel} className="background-tasks-panel" data-empty={!hasRecords} role="dialog" aria-label="后台任务" style={position}>
      <header><h3>后台任务</h3><div className="task-panel-actions">{canClear&&<ActionButton onClick={()=>{action('clearFinished');setHideScan(!state.importing);setUnread(false);}}>一键清理</ActionButton>}<IconButton label="关闭后台任务" onClick={()=>{setOpen(false);root.current?.querySelector('button')?.focus();}}><Icon name="close"/></IconButton></div></header>
      <p role="status">{active?`${active} 项进行中`:hasRecords?'所有后台任务已结束':'暂无后台任务'}</p>
      {hasRecords&&<div className="background-tasks-scroll">
        {tasks.modelStatus&&<div className="task-row"><Icon name="download"/><div><strong>AI 模型</strong><p>{tasks.modelStatus}</p>{tasks.downloadingModel&&tasks.modelProgress!=null&&<progress aria-label="模型下载进度" max={1} value={tasks.modelProgress}/>}</div>{tasks.downloadingModel?<span className="spinner"/>:<>{tasks.modelFailed&&<IconButton label="重试下载" disabled={active>0} onClick={()=>action('retryModel')}><Icon name="refresh"/></IconButton>}<IconButton label="清理下载记录" onClick={()=>action('clearModel')}><Icon name="close"/></IconButton></>}</div>}
        {hasScan&&<div className="task-row"><Icon name="folder"/><div><strong>扫描音乐库</strong><p>{state.scanSummary}</p>{Boolean(state.issues?.length)&&<Disclosure title={`${state.issues.length} 项无法读取`}>{state.issues.map((issue,index)=><p key={index}>{issue}</p>)}</Disclosure>}</div>{state.importing?<span className="spinner"/>:<>{Boolean(state.issues?.length)&&<IconButton label="重新扫描" onClick={()=>command('rescan')}><Icon name="refresh"/></IconButton>}<IconButton label="清理扫描记录" onClick={()=>setHideScan(true)}><Icon name="close"/></IconButton></>}</div>}
        {[...(state.jobs||[])].reverse().map(job=><div className="task-row" key={job.id}><Icon name="lyrics"/><div><strong>AI 歌词匹配 · {job.title}</strong><p>{job.detail}</p><small>{!job.finished?(job.detail==='等待处理'?'排队中':'进行中'):job.failed?'失败':'已结束'}</small></div>{!job.finished?<span className="spinner"/>:<>{job.failed&&<IconButton label="重试歌词匹配" disabled={tasks.downloadingModel} onClick={()=>action('retry',job.id)}><Icon name="refresh"/></IconButton>}<IconButton label="清理任务记录" onClick={()=>action('clear',job.id)}><Icon name="close"/></IconButton></>}</div>)}
        {tasks.notice&&<div className="task-row"><Icon name="tasks"/><div><strong>{tasks.notice.title}</strong><p>{tasks.notice.message}</p></div><IconButton label="清理状态提醒" onClick={()=>action('clearNotice')}><Icon name="close"/></IconButton></div>}
      </div>}
    </section>,document.body)}
  </span>;
}
