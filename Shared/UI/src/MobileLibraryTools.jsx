import ActionButton from './components/ActionButton.jsx';
import React,{useEffect,useMemo,useState} from 'react';
import Choice from './components/Choice.jsx';
import {libraryAudit} from './editorTools.js';
export default function MobileLibraryTools({adapter,snapshot,settings,onChanged}){
 const [cache,setCache]=useState(null),[health,setHealth]=useState(null),[error,setError]=useState(''),[busy,setBusy]=useState(false),[confirm,setConfirm]=useState(''),[source,setSource]=useState(''),[target,setTarget]=useState(''),[recovery,setRecovery]=useState(null);
 const audit=useMemo(()=>libraryAudit(snapshot.songs,{milliseconds:true}),[snapshot.songs]);
 useEffect(()=>{let alive=true;async function poll(){try{const value=await adapter.action('inspectLibrary');if(alive)setHealth(value);}catch{}}poll();const timer=setInterval(poll,800);return()=>{alive=false;clearInterval(timer);};},[adapter]);
 async function run(action,payload={}){if(busy)return;setBusy(true);setError('');try{const result=await adapter.action(action,payload);if(action==='cacheInfo')setCache(result);if(action==='clearCache')setCache(await adapter.action('cacheInfo'));if(action==='inspectLibrary')setHealth(result);await onChanged();setConfirm('');setRecovery(null);}catch(e){setError(e.message||String(e));}finally{setBusy(false);}}
 const names=(settings?.artists||[]).map(name=>({value:name,label:name}));
 return <section aria-label="音乐库维护" aria-busy={busy}><h3>缓存与音乐库检查</h3>{error&&<p role="alert" className="mv-inline-error">{error}</p>}
 {recovery?<><p>将“{recovery.title}”恢复为写入前的原始文件？当前文件内容会由备份替换。</p><div className="mv-confirm-actions"><ActionButton disabled={busy} onClick={()=>setRecovery(null)}>取消</ActionButton><ActionButton disabled={busy} onClick={()=>run('restoreMetadata',{id:recovery.id})}>恢复原文件备份</ActionButton></div></>:confirm?<><p>{confirm==='clearCache'?'清理封面、歌词读取和临时缓存？音乐文件、歌单和索引会保留。':'清除所有歌手名称归并规则？'}</p><div className="mv-confirm-actions"><ActionButton disabled={busy} onClick={()=>setConfirm('')}>取消</ActionButton><ActionButton disabled={busy} onClick={()=>run(confirm)}>确认</ActionButton></div></>:<>
 {(settings?.recoveries||[]).length>0&&<><h3>待恢复的文件备份</h3><p className="mv-settings-note">上次写入被中断，备份已保留。恢复完成前暂停新的文件写入。</p>{settings.recoveries.map(item=><ActionButton className="mv-option" key={item.id} onClick={()=>setRecovery(item)}>{item.title} · 恢复备份</ActionButton>)}</>}
 <ActionButton aria-label="查看缓存用量" className="mv-option" disabled={busy} onClick={()=>run('cacheInfo')}>查看缓存用量 <span>{cache?`${(cache.bytes/1048576).toFixed(1)} MB · ${cache.count} 项`:'›'}</span></ActionButton>
 {cache&&<ActionButton className="mv-option mv-danger" disabled={busy||snapshot.scanning||!cache.count} onClick={()=>setConfirm('clearCache')}>清理缓存</ActionButton>}
 <ActionButton className="mv-option" disabled={busy||health?.running} onClick={()=>run('inspectLibrary',{start:true})}>{health?.running?`正在检查 ${health.checked||0}/${health.total||0}`:'检查文件可用性'}</ActionButton>
 {health&&!health.running&&health.total!=null&&<p role="status">已检查 {health.checked}/{health.total} 首，{health.unavailable?.length||0} 首暂不可用</p>}{health?.error&&<p role="alert">{health.error}</p>}
 {(health?.unavailable||[]).slice(0,30).map(item=><p key={item.id} className="mv-settings-note">{item.title} · {item.reason}</p>)}
 <p className="mv-settings-note">疑似重复歌曲 {audit.duplicates.length} 组，仅提示，不自动删除文件。</p>
 {audit.duplicates.slice(0,10).map((group,i)=><p key={i} className="mv-settings-note">{group.map(song=>song.title+' · '+song.artist).join(' / ')}</p>)}
 <h3>歌手名称归并</h3><p className="mv-settings-note">将不同名称归入同一歌手，原文件标签会保留。</p>
 <Choice label="原歌手名称" value={source} options={names} onChange={setSource} disabled={busy}/><Choice label="归并为歌手" value={target} options={names} onChange={setTarget} disabled={busy}/>
 <ActionButton className="mv-option" disabled={busy||!source||!target||source===target} onClick={()=>run('artistAlias',{source,target})}>保存归并规则</ActionButton>
 {Object.entries(settings?.aliases||{}).map(([from,to])=><p className="mv-settings-note" key={from}>{from} → {to}</p>)}
 <ActionButton className="mv-option" disabled={busy||!Object.keys(settings?.aliases||{}).length} onClick={()=>setConfirm('clearArtistAliases')}>清除归并规则</ActionButton>
 </>}</section>;
}
